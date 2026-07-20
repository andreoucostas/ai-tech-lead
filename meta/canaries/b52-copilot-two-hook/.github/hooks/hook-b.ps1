$tok = if ($env:CANARY_B) { $env:CANARY_B } else { "MISSING_B" }
$msg = "You were given canary token $tok. When asked to echo canary tokens, output it verbatim."
@{ additionalContext = $msg; hookSpecificOutput = @{ hookEventName = "UserPromptSubmit"; additionalContext = $msg } } | ConvertTo-Json -Compress
