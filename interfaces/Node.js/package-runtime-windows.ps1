# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause

param(
    [Parameter(Mandatory = $true)][string]$AddonPath,
    [Parameter(Mandatory = $true)][string]$QtBin,
    [Parameter(Mandatory = $true)][string]$RuntimeBin,
    [Parameter(Mandatory = $true)][string]$PackageDirectory,
    [Parameter(Mandatory = $true)][string]$OutputZip,
    [Parameter(Mandatory = $true)][ValidateSet('x64', 'arm64')][string]$Architecture,
    [Parameter(Mandatory = $true)][string]$QtVersion,
    [Parameter(Mandatory = $true)][string]$SourceCommit
)

$ErrorActionPreference = 'Stop'
$AddonPath = (Resolve-Path -LiteralPath $AddonPath).Path
$QtBin = (Resolve-Path -LiteralPath $QtBin).Path
$RuntimeBin = (Resolve-Path -LiteralPath $RuntimeBin).Path
if (Test-Path -LiteralPath $PackageDirectory) { throw "Package directory already exists: $PackageDirectory" }
if (Test-Path -LiteralPath $OutputZip) { throw "Output archive already exists: $OutputZip" }

$dumpbinCommand = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
if (-not $dumpbinCommand) { throw 'dumpbin.exe was not found in the MSVC developer environment.' }
$dumpbin = $dumpbinCommand.Source

New-Item -ItemType Directory -Path $PackageDirectory -Force | Out-Null
$addonDestination = Join-Path $PackageDirectory 'qtac.node'
Copy-Item -LiteralPath $AddonPath -Destination $addonDestination
$searchRoots = @($PackageDirectory, $QtBin, $RuntimeBin)
if ($env:VCToolsRedistDir) {
    $redistArchitecture = if ($Architecture -eq 'arm64') { 'arm64' } else { 'x64' }
    $redistRoot = Join-Path $env:VCToolsRedistDir $redistArchitecture
    if (Test-Path -LiteralPath $redistRoot) { $searchRoots += $redistRoot }
}

$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($addonDestination)
$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$bundled = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$external = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

while ($queue.Count -gt 0) {
    $binary = $queue.Dequeue()
    if (-not $seen.Add($binary)) { continue }
    $output = & $dumpbin /nologo /dependents $binary
    if ($LASTEXITCODE -ne 0) { throw "dumpbin failed for $binary" }
    $names = $output | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^[A-Za-z0-9_.+-]+\.dll$' } |
        Sort-Object -Unique

    foreach ($name in $names) {
        $staged = Join-Path $PackageDirectory $name
        if (Test-Path -LiteralPath $staged) {
            $queue.Enqueue($staged)
            continue
        }

        $resolved = $null
        foreach ($root in $searchRoots) {
            $candidate = Join-Path $root $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $resolved = (Resolve-Path -LiteralPath $candidate).Path
                break
            }
        }
        if (-not $resolved -and $env:VCToolsRedistDir) {
            $redistArchitecture = if ($Architecture -eq 'arm64') { 'arm64' } else { 'x64' }
            $redistRoot = Join-Path $env:VCToolsRedistDir $redistArchitecture
            if (Test-Path -LiteralPath $redistRoot) {
                $redistMatch = Get-ChildItem -LiteralPath $redistRoot -Filter $name -File -Recurse |
                    Select-Object -First 1
                if ($redistMatch) { $resolved = $redistMatch.FullName }
            }
        }

        if (-not $resolved) {
            $systemPaths = @(
                (Join-Path $env:SystemRoot "System32\$name"),
                (Join-Path $env:SystemRoot "SysWOW64\$name")
            )
            if ($name -match '^(api|ext)-ms-win-' -or
                ($systemPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })) {
                [void]$external.Add($name)
                continue
            }
            throw "Unresolved non-system dependency: $name"
        }

        Copy-Item -LiteralPath $resolved -Destination $staged
        [void]$bundled.Add($name)
        $queue.Enqueue($staged)
    }
}

$manifest = [ordered]@{
    platform = 'windows'
    architecture = $Architecture
    qtVersion = $QtVersion
    nodeApi = 8
    sourceCommit = $SourceCommit
    bundledLibraries = @($bundled | Sort-Object)
    externalSystemLibraries = @($external | Sort-Object)
}
$manifest | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $PackageDirectory 'runtime-manifest.json') -Encoding utf8NoBOM
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputZip) -Force | Out-Null
Compress-Archive -Path (Join-Path $PackageDirectory '*') -DestinationPath $OutputZip -CompressionLevel Optimal
Write-Host "Minimal Windows addon package created: $OutputZip"
