param(
    [string]$SshTarget = "eric@api.ericburden.dev",
    [string]$IdentityFile = "$HOME/.ssh/id_ed25519",
    [string]$WorkspaceRoot = "/home/eric/elowen",
    [string]$UiTag = "",
    [switch]$SkipLocalBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$uiRoot = Join-Path $repoRoot "elowen-ui"
$buildScript = Join-Path $PSScriptRoot "build-prebuilt-images.ps1"

if ([string]::IsNullOrWhiteSpace($UiTag)) {
    $UiTag = "dev-ui-{0}" -f (Get-Date -Format "yyyyMMddHHmmss")
}

if (-not $SkipLocalBuild) {
    & $buildScript -UiOnly -UiTag $UiTag
    if ($LASTEXITCODE -ne 0) {
        throw "Local prebuilt UI image build failed."
    }
}

$sourceImage = "ghcr.io/elowen-assistant/elowen-ui:$UiTag"
$remoteImage = "elowen-ui:$UiTag"

Write-Host "==> Streaming $sourceImage to $SshTarget"
$streamCommand = "docker save $sourceImage | ssh -i `"$IdentityFile`" -o IdentitiesOnly=yes $SshTarget docker load"
cmd /c $streamCommand
if ($LASTEXITCODE -ne 0) {
    throw "Failed to stream the prebuilt UI image to the VPS."
}

$remoteScript = @"
set -eu
docker tag '$sourceImage' '$remoteImage'
cd '$WorkspaceRoot'
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  up -d --pull never elowen-api
ELOWEN_UI_IMAGE=elowen-ui ELOWEN_UI_TAG='$UiTag' docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  rm -sf elowen-ui
ELOWEN_UI_IMAGE=elowen-ui ELOWEN_UI_TAG='$UiTag' docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  up -d --no-deps --pull never elowen-ui
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  ps elowen-api elowen-ui
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep 'elowen-api\|elowen-ui'
"@

Write-Host "==> Restarting VPS services from prebuilt images"
$remoteScript -replace "`r", "" | & ssh.exe -i $IdentityFile -o IdentitiesOnly=yes $SshTarget "tr -d '\r' | bash"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to restart VPS services from the prebuilt UI image."
}

Write-Host ""
Write-Host "VPS UI image is now running from $remoteImage"
