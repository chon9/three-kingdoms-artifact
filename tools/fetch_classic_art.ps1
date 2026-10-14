param([switch]$Force)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $projectRoot 'assets\classic_cards'
$manifest = Get-Content -LiteralPath (Join-Path $assetRoot 'manifest.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $assetRoot -Force | Out-Null
foreach ($asset in $manifest.assets) {
    $target = Join-Path $assetRoot $asset.local_file
    if ($Force -or -not (Test-Path -LiteralPath $target)) {
        if (-not $asset.url.StartsWith('https://steamcdn-a.akamaihd.net/apps/583950/')) {
            throw ('Unexpected source URL for ' + $asset.name)
        }
        Invoke-WebRequest -Uri $asset.url -OutFile $target
        Write-Output ('Downloaded ' + $asset.name)
    }
}
