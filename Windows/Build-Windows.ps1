param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64'
)

$ErrorActionPreference = 'Stop'
$windowsRoot = $PSScriptRoot
$appProject = Join-Path $windowsRoot 'LanScope.Windows\LanScope.Windows.csproj'
$testProject = Join-Path $windowsRoot 'LanScope.Core.Tests\LanScope.Core.Tests.csproj'
$publishPath = Join-Path $windowsRoot "dist\$Runtime"

$dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnetCommand) {
    throw '.NET 8 SDK is required. Download it from https://dotnet.microsoft.com/download/dotnet/8.0'
}

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
& $dotnetCommand.Source run --project $testProject -c $Configuration
if ($LASTEXITCODE -ne 0) { throw 'LanScope.Core tests failed.' }

& $dotnetCommand.Source publish $appProject `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -o $publishPath
if ($LASTEXITCODE -ne 0) { throw 'LanScope Windows publish failed.' }

$zipPath = Join-Path $windowsRoot "dist\LanScope-Windows-$Runtime.zip"
Compress-Archive -Path (Join-Path $publishPath '*') -DestinationPath $zipPath -Force
Write-Host "Portable build: $publishPath"
Write-Host "Archive: $zipPath"

if ($Runtime -eq 'win-x64') {
    $innoCandidates = @(
        $env:INNO_SETUP_COMPILER,
        (Join-Path ${env:ProgramFiles} 'Inno Setup 7\ISCC.exe'),
        (Join-Path ${env:ProgramFiles} 'Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:LOCALAPPDATA} 'Programs\Inno Setup 7\ISCC.exe'),
        (Join-Path ${env:LOCALAPPDATA} 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $innoCompiler = $innoCandidates | Select-Object -First 1
    if (-not $innoCompiler) {
        $innoCommand = Get-Command iscc -ErrorAction SilentlyContinue
        if ($innoCommand) { $innoCompiler = $innoCommand.Source }
    }

    if ($innoCompiler) {
        & $innoCompiler (Join-Path $windowsRoot 'installer\LanScope.Windows.iss')
        if ($LASTEXITCODE -ne 0) { throw 'LanScope Windows installer build failed.' }
        Write-Host "Installer: $(Join-Path $windowsRoot 'dist\LanScope-Windows-Setup-x64.exe')"
    }
    else {
        Write-Warning 'Inno Setup compiler was not found. Portable ZIP was created; Setup.exe was skipped.'
    }
}
