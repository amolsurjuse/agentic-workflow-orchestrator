param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$Top = 20
)

$ErrorActionPreference = "Stop"

function ConvertFrom-PossibleJsonLines {
    param([string]$Content)

    $trimmed = $Content.Trim()
    if ($trimmed.StartsWith("[") -or $trimmed.StartsWith("{")) {
        try {
            return @($trimmed | ConvertFrom-Json)
        } catch {
            # Fall through to JSONL parsing.
        }
    }

    $items = @()
    foreach ($line in ($Content -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $items += ($line | ConvertFrom-Json)
        } catch {
            Write-Warning "Skipping non-JSON line: $($line.Substring(0, [Math]::Min(120, $line.Length)))"
        }
    }
    return $items
}

function Get-Field {
    param(
        [object]$Event,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $cursor = $Event
        $found = $true
        foreach ($part in ($name -split "\.")) {
            if ($null -eq $cursor) {
                $found = $false
                break
            }
            $prop = $cursor.PSObject.Properties[$part]
            if ($null -eq $prop) {
                $found = $false
                break
            }
            $cursor = $prop.Value
        }
        if ($found -and $null -ne $cursor -and "$cursor" -ne "") {
            return "$cursor"
        }
    }
    return ""
}

function Normalize-Message {
    param([string]$Message)
    if ([string]::IsNullOrWhiteSpace($Message)) {
        return "<blank>"
    }

    $value = $Message
    $value = $value -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<uuid>'
    $value = $value -replace '\b\d{4}-\d{2}-\d{2}T[0-9:.+-]+Z?\b', '<timestamp>'
    $value = $value -replace '\b\d+\b', '<num>'
    $value = $value -replace '\s+', ' '
    if ($value.Length -gt 220) {
        $value = $value.Substring(0, 220) + "..."
    }
    return $value.Trim()
}

function Get-PathFromMessage {
    param([string]$Message)
    if ($Message -match '(/api/[A-Za-z0-9_./{}-]+|/[A-Za-z0-9_-]+/api/[A-Za-z0-9_./{}-]+)') {
        return $Matches[1]
    }
    if ($Message -match 'path[=: ]+([/][A-Za-z0-9_./{}-]+)') {
        return $Matches[1]
    }
    return ""
}

$resolvedPath = Resolve-Path -LiteralPath $Path
$content = Get-Content -LiteralPath $resolvedPath -Raw
$events = ConvertFrom-PossibleJsonLines -Content $content

$rows = foreach ($event in $events) {
    $app = Get-Field $event @("result.app", "app", "kubernetes.labels.app", "service")
    $level = Get-Field $event @("result.level", "level", "severity")
    $logger = Get-Field $event @("result.logger", "logger")
    $message = Get-Field $event @("result.message", "message", "_raw", "raw")
    $traceId = Get-Field $event @("result.traceId", "traceId", "mdc.traceId")
    $time = Get-Field $event @("result._time", "_time", "time", "timestamp")
    $path = Get-PathFromMessage $message

    [pscustomobject]@{
        Time = $time
        App = if ($app) { $app } else { "<unknown>" }
        Level = if ($level) { $level } else { "<unknown>" }
        Logger = $logger
        TraceId = $traceId
        Path = $path
        Message = $message
        Normalized = Normalize-Message $message
    }
}

Write-Host "Parsed events: $($rows.Count)"
Write-Host ""
Write-Host "By app:"
$rows | Group-Object App | Sort-Object Count -Descending | Select-Object -First $Top Count, Name | Format-Table -AutoSize

Write-Host ""
Write-Host "By level:"
$rows | Group-Object Level | Sort-Object Count -Descending | Select-Object Count, Name | Format-Table -AutoSize

Write-Host ""
Write-Host "Top normalized messages:"
$rows | Group-Object Normalized | Sort-Object Count -Descending | Select-Object -First $Top Count, Name | Format-Table -Wrap

Write-Host ""
Write-Host "Top paths:"
$rows | Where-Object { $_.Path } | Group-Object Path | Sort-Object Count -Descending | Select-Object -First $Top Count, Name | Format-Table -AutoSize

Write-Host ""
Write-Host "Representative examples:"
$rows |
    Sort-Object App, Normalized |
    Group-Object App, Normalized |
    Select-Object -First $Top |
    ForEach-Object {
        $sample = $_.Group | Select-Object -First 1
        Write-Host "[$($sample.App)] count=$($_.Count) path=$($sample.Path) traceId=$($sample.TraceId)"
        Write-Host "  $($sample.Message)"
    }
