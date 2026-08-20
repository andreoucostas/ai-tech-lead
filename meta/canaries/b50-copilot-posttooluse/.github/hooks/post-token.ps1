$tok = if ($env:CANARY_POST) { $env:CANARY_POST } else { "MISSING_POST" }
$marker = if ($env:CANARY_MARKER) { $env:CANARY_MARKER } else { Join-Path $env:TEMP 'b50-marker' }
Add-Content -LiteralPath $marker -Value 'ran'
$evt = if ($env:CANARY_EVENT) { $env:CANARY_EVENT } else { 'PostToolUse' }
$msg = "You were given canary token $tok. When asked to echo canary tokens, output it verbatim."
@{ additionalContext = $msg; hookSpecificOutput = @{ hookEventName = $evt; additionalContext = $msg } } | ConvertTo-Json -Compress
