#Requires -Version 5.1
<#
.SYNOPSIS
    Extracts the managed solution package for review, replacing any previous output.

.EXAMPLE
    ./scripts/Extract-Solution.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Paths resolve against the repo, so the script behaves the same from any directory.
$repoRoot = Split-Path -Parent $PSScriptRoot
$zipPath = Join-Path $repoRoot 'solutions/TerrraformExampleSolution_managed.zip'
$destinationPath = Join-Path $repoRoot 'solutions/extracted/TerrraformExampleSolution_managed'

if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
    throw "Solution package not found: $zipPath"
}

if (Test-Path -LiteralPath $destinationPath) {
    Remove-Item -LiteralPath $destinationPath -Recurse -Force
}

New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $destinationPath -Force

$fileCount = (Get-ChildItem -LiteralPath $destinationPath -Recurse -File).Count
Write-Host "Extracted $fileCount files to $destinationPath"
