#requires -Version 7.0
<#
.SYNOPSIS
Records a deployment request for the given environment (writes .deploy/last-deploy.txt in the repository root).
#>
param([Parameter(Mandatory)][string]$Environment)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root '.deploy'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Set-Content -LiteralPath (Join-Path $dir 'last-deploy.txt') -Value "environment=$Environment time=$stamp" -Encoding utf8NoBOM
Write-Host "Deployment recorded for $Environment."
exit 0
