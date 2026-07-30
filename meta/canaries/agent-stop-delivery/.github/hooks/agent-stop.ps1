$token = if ($env:CANARY_AGENT_STOP_TOKEN) {
    $env:CANARY_AGENT_STOP_TOKEN
} else {
    "MISSING_AGENT_STOP_TOKEN"
}
$timestamp = [DateTime]::UtcNow.ToString("o")
Add-Content -LiteralPath ".canary-agent-stop-fired" -Value "FIRED turn-end $timestamp"
$message = "Turn-end canary token: $token. Echo this token verbatim if you receive it."
@{
    additionalContext = $message
    hookSpecificOutput = @{
        hookEventName = "agentStop"
        additionalContext = $message
    }
} | ConvertTo-Json -Compress
