# Stage 4: install the emulator + an x86_64 system image and create an AVD.
# Licenses are already pre-accepted by android-sdk-packages.ps1 (C:\Android\licenses).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root      = 'C:\Android'
$JdkDir    = Join-Path $Root 'jdk-17'
$CmdLatest = Join-Path $Root 'cmdline-tools\latest'
$sdkmgr    = Join-Path $CmdLatest 'bin\sdkmanager.bat'
$avdmgr    = Join-Path $CmdLatest 'bin\avdmanager.bat'
$Img       = 'system-images;android-35;google_apis;x86_64'
$AvdName   = 'fitquest'

$env:JAVA_HOME        = $JdkDir
$env:ANDROID_HOME     = $Root
$env:ANDROID_SDK_ROOT = $Root
$env:PATH             = "$JdkDir\bin;$CmdLatest\bin;$Root\platform-tools;$Root\emulator;$env:PATH"

function Log($m){ Write-Host ("[emu] {0}" -f $m) }

Log ("Installing emulator + system image: $Img")
& $sdkmgr --sdk_root=$Root 'emulator' $Img 2>&1 |
  Select-String -Pattern 'Installing|Unzipping|done|Warning|Error|not accept|Skipping' | Select-Object -Last 10

Log 'Installed packages (emulator/system-images):'
& $sdkmgr --sdk_root=$Root --list_installed 2>&1 | Select-String -Pattern 'emulator|system-images' | Select-Object -First 10

# Create the AVD (auto-answer the 'custom hardware profile?' prompt with 'no').
Log ("Creating AVD '$AvdName'...")
$existing = & $avdmgr list avd 2>&1 | Select-String -Pattern $AvdName
if ($existing) {
  Log "AVD '$AvdName' already exists, skipping create."
} else {
  'no' | & $avdmgr create avd -n $AvdName -k $Img -d 'pixel_6' --force 2>&1 | Select-Object -Last 5
}

Log 'AVD list:'
& $avdmgr list avd 2>&1 | Select-String -Pattern 'Name:|Based on:|Path:' | Select-Object -First 10
Log 'DONE'
