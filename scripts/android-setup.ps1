# FitQuest Android toolchain bootstrap (user-level, no admin/UAC required)
# Downloads a JDK 17 + Android command-line tools into C:\Android, installs SDK
# packages, accepts licenses, points Flutter at it. Idempotent-ish: skips existing.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # massively speeds up Invoke-WebRequest

$Root    = 'C:\Android'
$JdkDir  = Join-Path $Root 'jdk-17'
$CmdRoot = Join-Path $Root 'cmdline-tools'
$CmdLatest = Join-Path $CmdRoot 'latest'
$Dl      = Join-Path $Root 'downloads'
New-Item -ItemType Directory -Force -Path $Root,$Dl | Out-Null

function Log($m){ Write-Host ("[setup] {0}" -f $m) }

# --- 1. JDK 17 (Temurin, zip — no installer) ---
if (-not (Test-Path (Join-Path $JdkDir 'bin\java.exe'))) {
  $jdkZip = Join-Path $Dl 'jdk17.zip'
  if (-not (Test-Path $jdkZip)) {
    Log 'Downloading Temurin JDK 17...'
    Invoke-WebRequest -Uri 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' -OutFile $jdkZip
  }
  Log 'Extracting JDK...'
  $tmp = Join-Path $Dl 'jdk_x'
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  Expand-Archive -Path $jdkZip -DestinationPath $tmp -Force
  $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
  if (Test-Path $JdkDir) { Remove-Item -Recurse -Force $JdkDir }
  Move-Item $inner.FullName $JdkDir
  Remove-Item -Recurse -Force $tmp
} else { Log 'JDK already present, skipping.' }

$env:JAVA_HOME = $JdkDir
$env:PATH = "$JdkDir\bin;$env:PATH"
Log ("JAVA_HOME=$JdkDir")
& "$JdkDir\bin\java.exe" -version

# --- 2. Android command-line tools ---
if (-not (Test-Path (Join-Path $CmdLatest 'bin\sdkmanager.bat'))) {
  $cmdZip = Join-Path $Dl 'cmdline-tools.zip'
  if (-not (Test-Path $cmdZip)) {
    Log 'Downloading Android command-line tools...'
    Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $cmdZip
  }
  Log 'Extracting command-line tools...'
  $tmp = Join-Path $Dl 'cmd_x'
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  Expand-Archive -Path $cmdZip -DestinationPath $tmp -Force
  New-Item -ItemType Directory -Force -Path $CmdRoot | Out-Null
  if (Test-Path $CmdLatest) { Remove-Item -Recurse -Force $CmdLatest }
  # zip extracts to a 'cmdline-tools' folder; sdkmanager requires it under 'latest'
  Move-Item (Join-Path $tmp 'cmdline-tools') $CmdLatest
  Remove-Item -Recurse -Force $tmp
} else { Log 'cmdline-tools already present, skipping.' }

$env:ANDROID_HOME = $Root
$env:ANDROID_SDK_ROOT = $Root
$env:PATH = "$CmdLatest\bin;$Root\platform-tools;$env:PATH"

Log 'Bootstrap (JDK + cmdline-tools) complete.'
Log ("JDK : $JdkDir")
Log ("SDK : $Root")
