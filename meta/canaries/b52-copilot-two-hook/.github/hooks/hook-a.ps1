$tok = if ($env:CANARY_A) { $env:CANARY_A } else { "MISSING_A" }
$msg = "You were given canary token $tok. When asked to echo canary tokens, output it verbatim."
@{ additionalContext = $msg; hookSpecificOutput = @{ hookEventName = "UserPromptSubmit"; additionalContext = $msg } } | ConvertTo-Json -Compress
