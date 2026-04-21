param(
    [string]$SshTarget = "eric@api.ericburden.dev",
    [string]$IdentityFile = "$HOME/.ssh/id_ed25519",
    [string]$WorkspaceRoot = "/home/eric/elowen",
    [string]$ApiTag = "",
    [string]$UiTag = "",
    [switch]$SkipLocalBuild
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiTag)) {
    $ApiTag = "dev-api-{0}" -f (Get-Date -Format "yyyyMMddHHmmss")
}

if ([string]::IsNullOrWhiteSpace($UiTag)) {
    $UiTag = "dev-ui-{0}" -f (Get-Date -Format "yyyyMMddHHmmss")
}

$scriptRoot = $PSScriptRoot
$apiScript = Join-Path $scriptRoot "deploy-api-prebuilt.ps1"
$uiScript = Join-Path $scriptRoot "deploy-ui-prebuilt.ps1"

Write-Host "==> Deploying elowen-api via prebuilt image transfer"
$apiArgs = @{
    SshTarget = $SshTarget
    IdentityFile = $IdentityFile
    WorkspaceRoot = $WorkspaceRoot
    ApiTag = $ApiTag
}
if ($SkipLocalBuild) {
    $apiArgs.SkipLocalBuild = $true
}
& $apiScript @apiArgs
if ($LASTEXITCODE -ne 0) {
    throw "Prebuilt API deployment failed."
}

Write-Host ""
Write-Host "==> Deploying elowen-ui via prebuilt image transfer"
$uiArgs = @{
    SshTarget = $SshTarget
    IdentityFile = $IdentityFile
    WorkspaceRoot = $WorkspaceRoot
    UiTag = $UiTag
}
if ($SkipLocalBuild) {
    $uiArgs.SkipLocalBuild = $true
}
& $uiScript @uiArgs
if ($LASTEXITCODE -ne 0) {
    throw "Prebuilt UI deployment failed."
}

Write-Host ""
Write-Host "Dev VPS rollout complete."
Write-Host "  API image: elowen-api:$ApiTag"
Write-Host "  UI image:  elowen-ui:$UiTag"
