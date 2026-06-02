# Stage 2 (v3): pre-accept Android SDK licenses by writing the license hash files
# directly (CI-standard, prompt-free), then install packages.
# Run AFTER android-setup.ps1 has placed the JDK + cmdline-tools under C:\Android.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root      = 'C:\Android'
$JdkDir    = Join-Path $Root 'jdk-17'
$CmdLatest = Join-Path $Root 'cmdline-tools\latest'
$sdkmgr    = Join-Path $CmdLatest 'bin\sdkmanager.bat'

if (-not (Test-Path $JdkDir))  { throw "JDK not found at $JdkDir - run android-setup.ps1 first" }
if (-not (Test-Path $sdkmgr))  { throw "sdkmanager not found at $sdkmgr - run android-setup.ps1 first" }

$env:JAVA_HOME        = $JdkDir
$env:ANDROID_HOME     = $Root
$env:ANDROID_SDK_ROOT = $Root
$env:PATH             = "$JdkDir\bin;$CmdLatest\bin;$Root\platform-tools;$env:PATH"

function Log($m){ Write-Host ("[sdk] {0}" -f $m) }

# --- Pre-accept licenses by writing the well-known hash files ---
Log 'Writing license acceptance files...'
$licDir = Join-Path $Root 'licenses'
New-Item -ItemType Directory -Force -Path $licDir | Out-Null
$licenses = @{
  'android-sdk-license'             = @('24333f8a63b6825ea9c5514f83c2829b004d1fee','8933bad161af4178b1185d1a37fbf41ea5269c55','d56f5187479451eabf01fb78af6dfcb131a6481e')
  'android-sdk-preview-license'     = @('84831b9409646a918e30573bab4c9c91346d8abd','504667f4c0de7af1a06de9f4b1727b84351f2910')
  'android-googletv-license'        = @('601085b94cd77f0b54ff86406957099ebe79c4d6')
  'google-gdk-license'              = @('33b6a2b64607f11b759f320ef9dff4ae5c47d97a')
  'mips-android-sysimage-license'   = @('e9acab5b5fbb560a72cfaecce8946896ff6aab9d')
  'android-sdk-arm-dbt-license'     = @('859f317696f67ef3d7f30a50a5560e7834b43903')
}
foreach ($k in $licenses.Keys) {
  $body = ($licenses[$k] -join "`n")
  Set-Content -Path (Join-Path $licDir $k) -Value $body -NoNewline -Encoding ascii
}
Log ("Wrote " + $licenses.Count + " license files.")

# --- Install core packages (licenses already accepted -> no prompt) ---
$pkgs = @('platform-tools','platforms;android-36','platforms;android-35','build-tools;36.0.0','build-tools;35.0.0')
Log ("Installing: " + ($pkgs -join ', '))
& $sdkmgr --sdk_root=$Root @pkgs 2>&1 |
  Select-String -Pattern 'Installing|Unzipping|done|Warning|Error|not accept|Skipping' | Select-Object -Last 15

# --- Verify ---
Log 'Installed packages:'
& $sdkmgr --sdk_root=$Root --list_installed 2>&1 | Select-Object -First 25

# --- Point Flutter at SDK + persist user env vars ---
Log 'Configuring Flutter + persisting user env vars...'
& 'C:\flutter\bin\flutter.bat' config --android-sdk $Root --jdk-dir $JdkDir 2>&1 | Select-Object -Last 3
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $Root, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $Root, 'User')
[Environment]::SetEnvironmentVariable('JAVA_HOME', $JdkDir, 'User')

Log 'flutter doctor:'
& 'C:\flutter\bin\flutter.bat' doctor 2>&1 | Select-Object -First 14
Log 'DONE'
