# Java Expert Learning NotebookLM Video Direction

## Request

Improve the Java Expert Learning Markdown sources so NotebookLM produces technically logical, topic-specific videos instead of generic or random illustrations. Every video must make the production problem explicit, explain the diagnosis, show the causal mechanism, and finish with a detailed, testable solution.

## Approach

1. Add a shared NotebookLM production guide with source-selection, custom-prompt, style, and quality-gate instructions.
2. Add a self-contained production brief to every topic because each Markdown file may be used alone as a NotebookLM source.
3. Make each brief include:
   - The production question and concrete symptom.
   - A non-negotiable visual vocabulary tied to the Java concept.
   - A scene-by-scene sequence from problem through evidence, cause, solution, and verification.
   - Exact concepts to show on screen, avoiding decorative or unrelated imagery.
   - A detailed technical solution with observable proof.
4. Update the learning-path README with the recommended NotebookLM generation workflow and prompt.

## Verification

- Every expert topic contains a `NotebookLM Video Production Brief`.
- Every topic includes a clear problem, evidence, root cause, solution, and verification outcome.
- The guide tells the creator to use one topic per notebook and to select only the relevant source.
- The ready-to-paste prompt requires causal technical diagrams and bans generic office/server-room imagery.
