param(
    [string]$Registry = "ghcr.io/elowen-assistant",
    [string]$ApiTag = "",
    [string]$UiTag = "",
    [switch]$Push,
    [switch]$ApiOnly,
    [switch]$UiOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$apiRoot = Join-Path $repoRoot "elowen-api"
$uiRoot = Join-Path $repoRoot "elowen-ui"

$buildApi = -not $UiOnly
$buildUi = -not $ApiOnly

if (-not $buildApi -and -not $buildUi) {
    throw "Nothing selected to build."
}

function Invoke-CheckedCommand {
    param(
        [string]$Message,
        [string]$WorkingDirectory,
        [string[]]$Command,
        [hashtable]$Environment = @{}
    )

    Write-Host "==> $Message"
    Push-Location $WorkingDirectory
    try {
        $originalEnv = @{}
        foreach ($entry in $Environment.GetEnumerator()) {
            $name = [string]$entry.Key
            $originalEnv[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, [string]$entry.Value)
        }

        & $Command[0] $Command[1..($Command.Length - 1)]
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed: $($Command -join ' ')"
        }
    } finally {
        foreach ($entry in $originalEnv.GetEnumerator()) {
            [Environment]::SetEnvironmentVariable([string]$entry.Key, $entry.Value)
        }
        Pop-Location
    }
}

if ($buildApi -and [string]::IsNullOrWhiteSpace($ApiTag)) {
    $ApiTag = (& git -C $apiRoot rev-parse --short HEAD).Trim()
}

if ($buildUi -and [string]::IsNullOrWhiteSpace($UiTag)) {
    $UiTag = (& git -C $uiRoot rev-parse --short HEAD).Trim()
}

if ($buildApi) {
    $apiBuildDir = Join-Path $apiRoot "build"
    $apiBinary = Join-Path $apiRoot "target\release\elowen-api"
    $apiOutput = Join-Path $apiBuildDir "elowen-api"
    $apiImage = "$Registry/elowen-api:$ApiTag"
    $cargoTargetDir = "/src/target"

    Invoke-CheckedCommand `
        -Message "Building elowen-api Linux release binary locally" `
        -WorkingDirectory $apiRoot `
        -Command @(
            "docker", "run", "--rm",
            "-v", "${apiRoot}:/src",
            "-w", "/src",
            "-e", "CARGO_TARGET_DIR=$cargoTargetDir",
            "rust:1.88-bookworm",
            "bash", "-lc", "export PATH=/usr/local/cargo/bin:`$PATH && rm -rf /tmp/elowen-api-build && mkdir -p /tmp/elowen-api-build && cp -R /src/. /tmp/elowen-api-build && find /tmp/elowen-api-build/migrations -type f -name '*.sql' -exec sed -i 's/\r$//' {} + && cd /tmp/elowen-api-build && cargo build --release && cp /src/target/release/elowen-api /src/build/elowen-api"
        )

    New-Item -ItemType Directory -Force -Path $apiBuildDir | Out-Null
    if (-not (Test-Path $apiOutput)) {
        throw "Expected API binary at '$apiOutput' after cargo build."
    }

    Invoke-CheckedCommand `
        -Message "Building runtime-only API image $apiImage" `
        -WorkingDirectory $apiRoot `
        -Command @("docker", "build", "-f", "Dockerfile.prebuilt", "-t", $apiImage, ".")

    if ($Push) {
        Invoke-CheckedCommand `
            -Message "Pushing API image $apiImage" `
            -WorkingDirectory $apiRoot `
            -Command @("docker", "push", $apiImage)
    }
}

if ($buildUi) {
    $uiBuildDir = Join-Path $uiRoot "build"
    $uiDistDir = Join-Path $uiRoot "dist"
    $uiBuildOutput = Join-Path $uiBuildDir "dist"
    $uiImage = "$Registry/elowen-ui:$UiTag"

    Invoke-CheckedCommand `
        -Message "Building elowen-ui static assets locally" `
        -WorkingDirectory $uiRoot `
        -Command @("trunk", "build", "--release")

    if (-not (Test-Path $uiDistDir)) {
        throw "Expected UI dist output at '$uiDistDir' after trunk build."
    }

    New-Item -ItemType Directory -Force -Path $uiBuildDir | Out-Null
    if (Test-Path $uiBuildOutput) {
        Remove-Item $uiBuildOutput -Recurse -Force
    }
    Copy-Item $uiDistDir $uiBuildOutput -Recurse -Force

    Invoke-CheckedCommand `
        -Message "Building runtime-only UI image $uiImage" `
        -WorkingDirectory $uiRoot `
        -Command @("docker", "build", "-f", "Dockerfile.prebuilt", "-t", $uiImage, ".")

    if ($Push) {
        Invoke-CheckedCommand `
            -Message "Pushing UI image $uiImage" `
            -WorkingDirectory $uiRoot `
            -Command @("docker", "push", $uiImage)
    }
}

Write-Host ""
Write-Host "Built images:"
if ($buildApi) {
    Write-Host "  $Registry/elowen-api:$ApiTag"
}
if ($buildUi) {
    Write-Host "  $Registry/elowen-ui:$UiTag"
}
