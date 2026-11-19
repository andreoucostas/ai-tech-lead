<#
.SYNOPSIS
  A scripted model on 127.0.0.1 for free host checks: plays a fixed list of turns to Claude Code
  (Anthropic messages shape) and Copilot CLI (chat-completions shape). No real model is reached.
.DESCRIPTION
  -ScriptFile is JSON: { "turns": [ { "tool": "<name>", "input": { ... } }, { "text": "..." } ] }.
  The turn answered is the number of assistant messages already in the request, so retries and
  repeated requests get the same answer. A request that offers no tools (a host's side call, such
  as a title) gets plain text and does not use a turn. Every request is logged to -LogFile as one
  JSON line: method, path, header NAMES (never values), shape, model, offered tool names, turn.
  Usage is always 0. Writes "LISTENING <port>" to -ReadyFile once bound. Stops after -MaxSeconds.
  Started by host-smoke.ps1 (B-536).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScriptFile,
    [Parameter(Mandatory)][string]$LogFile,
    [Parameter(Mandatory)][string]$ReadyFile,
    [int]$Port = 0,
    [int]$MaxSeconds = 600
)
$ErrorActionPreference = 'Stop'

if ($Port -eq 0) {
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $Port = $probe.LocalEndpoint.Port; $probe.Stop()
}
$turns = @((Get-Content -LiteralPath $ScriptFile -Raw | ConvertFrom-Json -AsHashtable).turns)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Set-Content -LiteralPath $ReadyFile -Value "LISTENING $Port" -Encoding utf8NoBOM
$utf8 = [System.Text.UTF8Encoding]::new($false)
$deadline = [DateTime]::UtcNow.AddSeconds($MaxSeconds)
$seq = 0

function Write-Log([hashtable]$entry) {
    Add-Content -LiteralPath $LogFile -Value ($entry | ConvertTo-Json -Compress -Depth 5) -Encoding utf8NoBOM
}
function Send-Body($ctx, [int]$status, [string]$contentType, [string]$body) {
    $bytes = $utf8.GetBytes($body)
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = $contentType
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}
function ConvertTo-Json1($o) { $o | ConvertTo-Json -Compress -Depth 20 }

function Get-Turn($req, [string]$shape) {
    $tools = @($req['tools'] | Where-Object { $_ })
    if ($tools.Count -eq 0) { return @{ index = -1; turn = @{ text = 'ok' } } }
    $n = @($req['messages'] | Where-Object { $_ -and $_['role'] -eq 'assistant' }).Count
    if ($n -lt $turns.Count) { return @{ index = $n; turn = $turns[$n] } }
    return @{ index = $n; turn = @{ text = 'Done.' } }
}

function Get-AnthropicReply($req, $turn, [string]$id) {
    $model = [string]$req['model']
    if ($turn.ContainsKey('tool')) {
        $block = @{ type = 'tool_use'; id = "toolu_$id"; name = $turn.tool; input = $turn.input }
        $stop = 'tool_use'
    } else {
        $block = @{ type = 'text'; text = [string]$turn.text }
        $stop = 'end_turn'
    }
    $usage = @{ input_tokens = 0; output_tokens = 0; cache_creation_input_tokens = 0; cache_read_input_tokens = 0 }
    if (-not $req['stream']) {
        return @('application/json', (ConvertTo-Json1 @{ id = "msg_$id"; type = 'message'; role = 'assistant'; model = $model
            content = @($block); stop_reason = $stop; stop_sequence = $null; usage = $usage }))
    }
    $ev = [System.Collections.Generic.List[string]]::new()
    $add = { param($name, $data) $ev.Add("event: $name`ndata: $(ConvertTo-Json1 $data)`n`n") }
    & $add 'message_start' @{ type = 'message_start'; message = @{ id = "msg_$id"; type = 'message'; role = 'assistant'
        model = $model; content = @(); stop_reason = $null; stop_sequence = $null; usage = $usage } }
    if ($block.type -eq 'tool_use') {
        & $add 'content_block_start' @{ type = 'content_block_start'; index = 0
            content_block = @{ type = 'tool_use'; id = $block.id; name = $block.name; input = @{} } }
        & $add 'content_block_delta' @{ type = 'content_block_delta'; index = 0
            delta = @{ type = 'input_json_delta'; partial_json = (ConvertTo-Json1 $block.input) } }
    } else {
        & $add 'content_block_start' @{ type = 'content_block_start'; index = 0; content_block = @{ type = 'text'; text = '' } }
        & $add 'content_block_delta' @{ type = 'content_block_delta'; index = 0; delta = @{ type = 'text_delta'; text = $block.text } }
    }
    & $add 'content_block_stop' @{ type = 'content_block_stop'; index = 0 }
    & $add 'message_delta' @{ type = 'message_delta'; delta = @{ stop_reason = $stop; stop_sequence = $null }; usage = @{ output_tokens = 0 } }
    & $add 'message_stop' @{ type = 'message_stop' }
    return @('text/event-stream', ($ev -join ''))
}

function Get-ChatReply($req, $turn, [string]$id) {
    $model = [string]$req['model']
    $created = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $usage = @{ prompt_tokens = 0; completion_tokens = 0; total_tokens = 0 }
    if ($turn.ContainsKey('tool')) {
        $call = @{ id = "call_$id"; type = 'function'; function = @{ name = $turn.tool; arguments = (ConvertTo-Json1 $turn.input) } }
        $message = @{ role = 'assistant'; content = $null; tool_calls = @($call) }
        $finish = 'tool_calls'
    } else {
        $message = @{ role = 'assistant'; content = [string]$turn.text }
        $finish = 'stop'
    }
    if (-not $req['stream']) {
        return @('application/json', (ConvertTo-Json1 @{ id = "chatcmpl-$id"; object = 'chat.completion'; created = $created
            model = $model; choices = @(@{ index = 0; message = $message; finish_reason = $finish }); usage = $usage }))
    }
    $chunk = { param($delta, $fin, $u)
        $c = @{ id = "chatcmpl-$id"; object = 'chat.completion.chunk'; created = $created; model = $model
            choices = @(@{ index = 0; delta = $delta; finish_reason = $fin }) }
        if ($u) { $c.usage = $u }
        "data: $(ConvertTo-Json1 $c)`n`n" }
    $delta = @{ role = 'assistant' }
    if ($message.ContainsKey('tool_calls')) {
        $delta.content = $null
        $delta.tool_calls = @(@{ index = 0; id = $call.id; type = 'function'; function = $call.function })
    } else { $delta.content = $message.content }
    $body = (& $chunk $delta $null $null) + (& $chunk @{} $finish $usage) + "data: [DONE]`n`n"
    return @('text/event-stream', $body)
}

try {
    while ([DateTime]::UtcNow -lt $deadline) {
        $task = $listener.GetContextAsync()
        while (-not $task.Wait(500)) { if ([DateTime]::UtcNow -ge $deadline) { break } }
        if (-not $task.IsCompleted) { break }
        $ctx = $task.Result
        $seq++
        $method = $ctx.Request.HttpMethod
        $path = $ctx.Request.Url.AbsolutePath
        $entry = [ordered]@{ seq = $seq; time = [DateTime]::UtcNow.ToString('o'); method = $method; path = $path
            query = $ctx.Request.Url.Query; headers = @($ctx.Request.Headers.AllKeys | Sort-Object) }
        try {
            $raw = ''
            if ($ctx.Request.HasEntityBody) {
                $reader = [System.IO.StreamReader]::new($ctx.Request.InputStream, $utf8)
                $raw = $reader.ReadToEnd(); $reader.Close()
            }
            $req = if ($raw) { $raw | ConvertFrom-Json -AsHashtable -Depth 100 } else { @{} }
            $entry.bytes = $raw.Length
            if ($method -eq 'POST' -and $path -match '/messages/count_tokens$') {
                $entry.shape = 'anthropic-count'
                Send-Body $ctx 200 'application/json' '{"input_tokens":0}'
            } elseif ($method -eq 'POST' -and $path -match '/messages$') {
                $pick = Get-Turn $req 'anthropic'
                $entry.shape = 'anthropic'; $entry.model = $req['model']; $entry.stream = [bool]$req['stream']
                $entry.tools = @($req['tools']).Count; $entry.turn = $pick.index
                $entry.toolNames = @($req['tools'] | Where-Object { $_ } | ForEach-Object { [string]$_['name'] })
                $entry.reply = if ($pick.turn.ContainsKey('tool')) { "tool:$($pick.turn.tool)" } else { 'text' }
                $r = Get-AnthropicReply $req $pick.turn "$seq"
                Send-Body $ctx 200 $r[0] $r[1]
            } elseif ($method -eq 'POST' -and $path -match '/chat/completions$') {
                $pick = Get-Turn $req 'chat'
                $entry.shape = 'chat'; $entry.model = $req['model']; $entry.stream = [bool]$req['stream']
                $entry.tools = @($req['tools']).Count; $entry.turn = $pick.index
                $entry.toolNames = @($req['tools'] | Where-Object { $_ } | ForEach-Object { [string]$_['function']['name'] })
                $entry.reply = if ($pick.turn.ContainsKey('tool')) { "tool:$($pick.turn.tool)" } else { 'text' }
                $r = Get-ChatReply $req $pick.turn "$seq"
                Send-Body $ctx 200 $r[0] $r[1]
            } elseif ($method -eq 'GET' -and $path -match '/models$') {
                $entry.shape = 'models'
                Send-Body $ctx 200 'application/json' '{"object":"list","data":[{"id":"scripted-model","object":"model","owned_by":"local"}]}'
            } else {
                $entry.shape = 'unknown'
                Send-Body $ctx 404 'application/json' '{"error":{"type":"not_found","message":"scripted endpoint"}}'
            }
        } catch {
            $entry.error = $_.Exception.Message
            try { Send-Body $ctx 500 'application/json' '{"error":{"type":"api_error","message":"scripted endpoint error"}}' } catch { }
        }
        Write-Log $entry
    }
} finally {
    $listener.Stop()
}
