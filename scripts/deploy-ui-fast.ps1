param(
    [string]$SshTarget = "eric@api.ericburden.dev",
    [string]$IdentityFile = "$HOME/.ssh/id_ed25519",
    [string]$WorkspaceRoot = "/home/eric/elowen",
    [string]$LocalUiPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LocalUiPath)) {
    $LocalUiPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\elowen-ui")).Path
}

if (-not (Test-Path (Join-Path $LocalUiPath "Dockerfile"))) {
    throw "Could not find elowen-ui at '$LocalUiPath'. Pass -LocalUiPath explicitly."
}

$overridePath = "/tmp/elowen-ui-fast-compose.yml"
$remoteSourcePath = "/tmp/elowen-ui-fast-src"
$archivePath = Join-Path $env:TEMP "elowen-ui-fast.tar"

try {
    tar -cf $archivePath --exclude=.git -C $LocalUiPath .
    scp -i $IdentityFile -o IdentitiesOnly=yes $archivePath "${SshTarget}:/tmp/elowen-ui-fast.tar" | Out-Null
} finally {
    if (Test-Path $archivePath) {
        Remove-Item $archivePath -Force
    }
}

$remoteScript = @"
set -euo pipefail
rm -rf '$remoteSourcePath'
mkdir -p '$remoteSourcePath'
tar -xf /tmp/elowen-ui-fast.tar -C '$remoteSourcePath'
cat > '$overridePath' <<'EOF'
services:
  elowen-ui:
    build:
      context: $remoteSourcePath
      dockerfile: Dockerfile
    image: elowen-ui:dev-vps
EOF
cd '$WorkspaceRoot'
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  -f '$overridePath' \
  build elowen-ui
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  -f '$overridePath' \
  up -d elowen-ui
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  -f '$overridePath' \
  ps elowen-ui
rm -f /tmp/elowen-ui-fast.tar
"@

ssh -i $IdentityFile -o IdentitiesOnly=yes $SshTarget $remoteScript
