param(
    [Parameter(Mandatory)] [string]$VCRuntime,
    [string]$PackageSource,
    [string]$OutputDirectory,
    [string]$Compiler = (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 6\ISCC.exe')
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath "$PSScriptRoot\..").Path
$Version = (Get-Content -Raw -LiteralPath (Join-Path $Root 'VERSION')).Trim()
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION must contain a numeric release version.' }
if (-not $PackageSource) { $PackageSource = Join-Path $Root "dist\DaguaBC-$Version" }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $Root "dist\DaguaBC-$Version-Windows-setup-local" }

$PackageSource = (Resolve-Path -LiteralPath $PackageSource).Path
$VCRuntime = (Resolve-Path -LiteralPath $VCRuntime).Path
foreach ($relative in @(
    'DaguaBC.exe', 'flutter_windows.dll', 'data\app.so', 'runtime\python\python.exe',
    'runtime\bin\ffmpeg.exe', 'runtime\bin\ffprobe.exe', 'runtime\models\bball_model.pt',
    'runtime\models\bball_model.onnx', 'LICENSE', 'NOTICE', 'SourceHanSans-LICENSE.txt'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageSource $relative) -PathType Leaf)) {
        throw "Package file missing: $relative"
    }
}
$App = Get-Item -LiteralPath (Join-Path $PackageSource 'DaguaBC.exe')
if ($App.VersionInfo.ProductVersion -notmatch ('^' + [regex]::Escape($Version) + '\+\d+$')) {
    throw "The application product version does not match VERSION: $($App.VersionInfo.ProductVersion)"
}
foreach ($name in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $VCRuntime $name) -PathType Leaf)) {
        throw "Visual C++ runtime file missing: $name"
    }
}
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if ($OutputDirectory -eq $PackageSource -or $OutputDirectory.StartsWith($PackageSource + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose an installer output directory outside the source package.'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$BaseName = "DaguaBC-$Version-Windows-x64-Setup"
$Installer = Join-Path $OutputDirectory "$BaseName.exe"
if (Test-Path -LiteralPath $Installer) { throw "Installer already exists: $Installer" }

$CompileArguments = @(
    '/Qp', "/DAppVersion=$Version", "/DPackageSource=$PackageSource", "/DVCRuntime=$VCRuntime",
    "/O$OutputDirectory", "/F$BaseName", (Join-Path $PSScriptRoot 'daguabc_windows_installer.iss')
)
& $Compiler @CompileArguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Installer -PathType Leaf)) {
    throw 'Inno Setup did not produce a complete installer.'
}
$Hash = (Get-FileHash -LiteralPath $Installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$Hash  $BaseName.exe" | Set-Content -LiteralPath "$Installer.sha256" -Encoding ascii
Write-Output "Installer created: $Installer"
