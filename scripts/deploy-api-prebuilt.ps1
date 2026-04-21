param(
    [string]$SshTarget = "eric@api.ericburden.dev",
    [string]$IdentityFile = "$HOME/.ssh/id_ed25519",
    [string]$WorkspaceRoot = "/home/eric/elowen",
    [string]$ApiTag = "",
    [switch]$SkipLocalBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$buildScript = Join-Path $PSScriptRoot "build-prebuilt-images.ps1"

if ([string]::IsNullOrWhiteSpace($ApiTag)) {
    $ApiTag = "dev-api-{0}" -f (Get-Date -Format "yyyyMMddHHmmss")
}

if (-not $SkipLocalBuild) {
    & $buildScript -ApiOnly -ApiTag $ApiTag
    if ($LASTEXITCODE -ne 0) {
        throw "Local prebuilt API image build failed."
    }
}

$sourceImage = "ghcr.io/elowen-assistant/elowen-api:$ApiTag"
$remoteImage = "elowen-api:$ApiTag"

Write-Host "==> Streaming $sourceImage to $SshTarget"
$streamCommand = "docker save $sourceImage | ssh -i `"$IdentityFile`" -o IdentitiesOnly=yes $SshTarget docker load"
cmd /c $streamCommand
if ($LASTEXITCODE -ne 0) {
    throw "Failed to stream the prebuilt API image to the VPS."
}

$remoteScript = @"
set -eu
docker tag '$sourceImage' '$remoteImage'
cd '$WorkspaceRoot'
ELOWEN_API_IMAGE=elowen-api ELOWEN_API_TAG='$ApiTag' docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  rm -sf elowen-api
ELOWEN_API_IMAGE=elowen-api ELOWEN_API_TAG='$ApiTag' docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  up -d --pull never elowen-api
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  ps elowen-api
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep 'elowen-api'
"@

Write-Host "==> Restarting VPS API service from prebuilt image"
$remoteScript -replace "`r", "" | & ssh.exe -i $IdentityFile -o IdentitiesOnly=yes $SshTarget "tr -d '\r' | bash"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to restart the VPS API service from the prebuilt image."
}

Write-Host ""
Write-Host "VPS API image is now running from $remoteImage"
