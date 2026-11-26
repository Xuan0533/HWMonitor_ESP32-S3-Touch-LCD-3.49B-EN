# All downloads/caches are local to this release; no persistent PATH changes.
$script:ToolsRoot=Join-Path $PSScriptRoot '.tools'
function Invoke-Checked { param([string]$Exe,[string[]]$Arguments); & $Exe @Arguments; if ($LASTEXITCODE -ne 0) {throw "Command failed ($LASTEXITCODE): $Exe"} }
function Assert-LocalDir([string]$Path) {
    if ((Test-Path -LiteralPath $Path) -and ((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw "Refusing linked directory: $Path"}
}
function Get-Download([string]$Url,[string]$Name) {
    Assert-LocalDir $script:ToolsRoot
    $dir=Join-Path $script:ToolsRoot 'downloads'; Assert-LocalDir $dir
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $file=Join-Path $dir $Name
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $old=$ProgressPreference; $ProgressPreference='SilentlyContinue'
    try {Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile "$file.part"; Move-Item -LiteralPath "$file.part" -Destination $file -Force} finally {$ProgressPreference=$old}
    return $file
}
function Get-PrivatePython {
    $dir=Join-Path $script:ToolsRoot 'python'; Assert-LocalDir $dir
    $py=Join-Path $dir 'tools\python.exe'
    if (!(Test-Path -LiteralPath $py)) {
        $zip=Get-Download 'https://api.nuget.org/v3-flatcontainer/python/3.13.17/python.3.13.17.nupkg' 'python-3.13.17.zip'
        Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
    }
    if (!(Test-Path -LiteralPath $py)) {throw 'Private Python package is incomplete.'}
    return $py
}
function Set-LocalDotnetEnv {
    Assert-LocalDir $script:ToolsRoot
    $env:DOTNET_CLI_HOME=Join-Path $script:ToolsRoot 'dotnet-home'
    $env:NUGET_PACKAGES=Join-Path $script:ToolsRoot 'nuget'
    $env:NUGET_HTTP_CACHE_PATH=Join-Path $script:ToolsRoot 'nuget-http'
    $env:NUGET_PLUGINS_CACHE_PATH=Join-Path $script:ToolsRoot 'nuget-plugins'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT='1'; $env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
}
function Find-Dotnet11 {
    foreach ($p in @((Join-Path $script:ToolsRoot 'dotnet\dotnet.exe'),(Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'))) {
        if (Test-Path -LiteralPath $p) {$sdk=& $p --list-sdks; if ($LASTEXITCODE -eq 0 -and ($sdk -match '^11\.')) {return $p}}
    }
}
function Get-Dotnet11 {
    Set-LocalDotnetEnv
    $dotnet=Find-Dotnet11
    if (!$dotnet) {
        $dir=Join-Path $script:ToolsRoot 'dotnet'; Assert-LocalDir $dir
        $installerScript=Get-Download 'https://dot.net/v1/dotnet-install.ps1' 'dotnet-install.ps1'
        Invoke-Checked (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') @('-NoProfile','-ExecutionPolicy','Bypass','-File',$installerScript,'-Version','11.0.100','-Architecture','x64','-InstallDir',$dir,'-NoPath') | Out-Host
        $dotnet=Find-Dotnet11
        if (!$dotnet) {throw 'Local .NET SDK 11 could not be detected.'}
    }
    return $dotnet
}
function Set-ArduinoEnv {
    Assert-LocalDir $script:ToolsRoot
    $env:ARDUINO_DIRECTORIES_DATA=Join-Path $script:ToolsRoot 'arduino-data'
    $env:ARDUINO_DIRECTORIES_DOWNLOADS=Join-Path $script:ToolsRoot 'arduino-downloads'
    $env:ARDUINO_DIRECTORIES_USER=Join-Path $script:ToolsRoot 'arduino-user'
}
function Get-ArduinoCli {
    Set-ArduinoEnv
    $dir=Join-Path $script:ToolsRoot 'arduino-cli'; Assert-LocalDir $dir
    $exe=Join-Path $dir 'arduino-cli.exe'
    if (!(Test-Path -LiteralPath $exe)) {
        $zip=Get-Download 'https://github.com/arduino/arduino-cli/releases/download/v1.6.0/arduino-cli_1.6.0_Windows_64bit.zip' 'arduino-cli-1.6.0.zip'
        Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
    }
    if (!(Test-Path -LiteralPath $exe)) {throw 'Arduino CLI archive incomplete.'}
    return $exe
}
