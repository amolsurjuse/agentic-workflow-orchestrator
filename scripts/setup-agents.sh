#!/bin/bash
# ─────────────────────────────────────────────────────────────
# setup-agents.sh
# Installs the Agentic Workflow Orchestrator into a target project.
#
# What it does:
#   1. Copies all .agent.md + agent-rules.md into <target>/.github/agents/
#   2. Copies SKILL.md files into <target>/.github/agents/skills/
#   3. Copies Jira/PR templates into <target>/.ai/
#   4. Copies references into <target>/.github/agents/references/
#   5. Copies templates/agent-commands.yml to <target>/docs/ (if not exists)
#   6. Creates /agentWork/ directory for agent outputs
#   7. Adds .github/agents/ and agentWork/ to <target>/.gitignore (idempotent)
#
# Usage:
#   cd /path/to/your-project
#   bash /path/to/agentic-workflow-orchestrator/scripts/setup-agents.sh
#
#   Or with explicit target:
#   bash setup-agents.sh /path/to/your-project
# ─────────────────────────────────────────────────────────────

set -euo pipefail
shopt -s nullglob

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$(pwd)}"

echo "========================================="
echo "  Agentic Workflow Orchestrator Setup"
echo "========================================="
echo ""
echo "  Source:  $REPO_DIR"
echo "  Target:  $TARGET_DIR"
echo ""

# Validate source
if [ ! -d "$REPO_DIR/.github/agents" ]; then
    echo "ERROR: Cannot find agents in $REPO_DIR/.github/agents"
    echo "       Make sure you're running this from the orchestrator repo."
    exit 1
fi

# Validate target
if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Target directory does not exist: $TARGET_DIR"
    exit 1
fi

# ── Step 1: Clean legacy orchestrator artifacts ──
echo "[1/8] Cleaning legacy orchestrator artifacts..."
AGENTS_DEST="$TARGET_DIR/.github/agents"
mkdir -p "$AGENTS_DEST"

LEGACY_CLEANED=0

# Remove legacy numbered agent files from previous installer versions.
for f in "$AGENTS_DEST"/[0-9][0-9]-*.agent.md; do
    [ -f "$f" ] || continue
    rm -f "$f"
    echo "      Removed legacy file: $(basename "$f")"
    LEGACY_CLEANED=$((LEGACY_CLEANED + 1))
done

# Remove legacy top-level directories (for example 01-requirements-agent/).
for d in "$AGENTS_DEST"/[0-9][0-9]-*; do
    [ -d "$d" ] || continue
    rm -rf "$d"
    echo "      Removed legacy directory: $(basename "$d")/"
    LEGACY_CLEANED=$((LEGACY_CLEANED + 1))
done

# Remove legacy numbered skill folders.
for d in "$AGENTS_DEST"/skills/agents/[0-9][0-9]-*; do
    [ -d "$d" ] || continue
    rm -rf "$d"
    echo "      Removed legacy skill folder: skills/agents/$(basename "$d")/"
    LEGACY_CLEANED=$((LEGACY_CLEANED + 1))
done

if [ "$LEGACY_CLEANED" -eq 0 ]; then
    echo "      No legacy artifacts found"
else
    echo "      Removed $LEGACY_CLEANED legacy artifacts"
fi
echo ""

# ── Step 2: Copy .agent.md files + agent-rules.md ──
echo "[2/8] Copying agent definitions (.agent.md + rules)..."
COUNT=0
for f in "$REPO_DIR/.github/agents"/*.agent.md; do
    [ -f "$f" ] || continue
    cp "$f" "$AGENTS_DEST/"
    NAME=$(grep "^name:" "$f" | head -1 | sed 's/name: //')
    echo "      $(basename "$f") → $NAME"
    COUNT=$((COUNT + 1))
done

# Copy agent-rules.md
if [ -f "$REPO_DIR/.github/agents/agent-rules.md" ]; then
    cp "$REPO_DIR/.github/agents/agent-rules.md" "$AGENTS_DEST/"
    echo "      agent-rules.md (shared rules)"
fi

echo "      Copied $COUNT agent files + rules"
echo ""

# ── Step 3: Copy SKILL.md files ──
echo "[3/8] Copying skill definitions (SKILL.md)..."
SKILLS_DEST="$TARGET_DIR/.github/agents/skills"
mkdir -p "$SKILLS_DEST"

# Copy orchestrator SKILL.md
if [ -f "$REPO_DIR/skills/SKILL.md" ]; then
    cp "$REPO_DIR/skills/SKILL.md" "$SKILLS_DEST/"
    echo "      skills/SKILL.md (orchestrator)"
fi

# Copy individual agent SKILL.md files
SKILL_COUNT=0
for d in "$REPO_DIR/skills/agents"/*/; do
    [ -d "$d" ] || continue
    agent_name=$(basename "$d")
    mkdir -p "$SKILLS_DEST/agents/$agent_name"
    cp "$d/SKILL.md" "$SKILLS_DEST/agents/$agent_name/"
    echo "      skills/agents/$agent_name/SKILL.md"
    SKILL_COUNT=$((SKILL_COUNT + 1))
done
echo "      Copied $SKILL_COUNT skill files"
echo ""

# ── Step 4: Copy references ──
echo "[4/8] Copying references..."
REFS_DEST="$TARGET_DIR/.github/agents/references"
mkdir -p "$REFS_DEST"

REF_COUNT=0
for f in "$REPO_DIR/skills/references"/*; do
    [ -f "$f" ] || continue
    cp "$f" "$REFS_DEST/"
    echo "      $(basename "$f")"
    REF_COUNT=$((REF_COUNT + 1))
done
echo "      Copied $REF_COUNT reference files"
echo ""

# ── Step 5: Copy templates ──
echo "[5/8] Copying templates..."
TEMPLATES_DEST="$TARGET_DIR/.ai"
mkdir -p "$TEMPLATES_DEST"

TPL_COUNT=0
for f in "$REPO_DIR/templates"/*; do
    [ -f "$f" ] || continue
    # agent-commands.yml is installed once into /docs to avoid drift.
    if [ "$(basename "$f")" = "agent-commands.yml" ]; then
        continue
    fi
    cp "$f" "$TEMPLATES_DEST/"
    echo "      $(basename "$f")"
    TPL_COUNT=$((TPL_COUNT + 1))
done
echo "      Copied $TPL_COUNT template files"
echo ""

# ── Step 6: Copy agent-commands.yml template ──
echo "[6/8] Setting up docs/agent-commands.yml..."
COMMANDS_FILE="$TARGET_DIR/docs/agent-commands.yml"
if [ -f "$COMMANDS_FILE" ]; then
    echo "      agent-commands.yml already exists — skipping"
else
    if [ ! -f "$REPO_DIR/templates/agent-commands.yml" ]; then
        echo "ERROR: Missing template file: $REPO_DIR/templates/agent-commands.yml"
        exit 1
    fi
    mkdir -p "$TARGET_DIR/docs"
    cp "$REPO_DIR/templates/agent-commands.yml" "$COMMANDS_FILE"
    echo "      Created docs/agent-commands.yml from templates/agent-commands.yml"
fi

# Ensure token-saver paths block exists even for pre-existing files.
if grep -Eq '^paths:' "$COMMANDS_FILE"; then
    echo "      paths block already exists"
else
    TMP_FILE="$(mktemp)"
    {
        cat <<'EOF'
# Token-saver path profile
paths:
  root: "."
  docs: "./docs"
  agent_work: "./agentWork"
  agents: "./.github/agents"

EOF
        cat "$COMMANDS_FILE"
    } > "$TMP_FILE"
    mv "$TMP_FILE" "$COMMANDS_FILE"
    echo "      Added paths block to docs/agent-commands.yml"
fi
echo ""

# ── Step 7: Create agentWork directory ──
echo "[7/8] Creating agentWork directory..."
mkdir -p "$TARGET_DIR/agentWork"
echo "      Created /agentWork/ for agent output persistence"
echo ""

# ── Step 8: Ensure .gitignore contains generated paths ──
echo "[8/8] Updating .gitignore with generated paths..."
GITIGNORE_FILE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE_FILE"

ensure_gitignore_entry() {
    local entry="$1"
    if grep -Fxq "$entry" "$GITIGNORE_FILE"; then
        echo "      .gitignore already has: $entry"
    else
        printf "%s\n" "$entry" >> "$GITIGNORE_FILE"
        echo "      Added to .gitignore: $entry"
    fi
}

ensure_gitignore_entry ".github/agents/"
ensure_gitignore_entry "agentWork/"
echo ""

# ── Summary ──
echo "========================================="
echo "  Setup Complete"
echo "========================================="
echo ""
echo "  Installed to: $TARGET_DIR"
echo ""
echo "  Files copied:"
echo "    legacy cleanup                 $LEGACY_CLEANED removed"
echo "    .github/agents/*.agent.md      $COUNT agents + rules"
echo "    .github/agents/skills/         $SKILL_COUNT skill files"
echo "    .github/agents/references/     $REF_COUNT reference files"
echo "    .ai/                           $TPL_COUNT templates (without agent-commands.yml)"
echo "    docs/agent-commands.yml        command reference"
echo "    agentWork/                     output directory"
echo "    .gitignore                     generated paths ensured"
echo ""
echo "  Installed agents:"
for f in "$REPO_DIR/.github/agents"/*.agent.md; do
    [ -f "$f" ] || continue
    name=$(grep "^name:" "$f" | head -1 | sed 's/name: //')
    echo "    $name"
done | sort
echo ""
echo "  Next steps:"
echo "    1. Edit docs/agent-commands.yml for your project's commands"
echo "    2. Restart your VS Code / Claude Code session"
echo "    3. Start: @f1.workspace-prep <JIRA_KEY> <short description>"
echo ""
echo "Done."
