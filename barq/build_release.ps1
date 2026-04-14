[CmdletBinding()]
param(
  [string]$GroqApiKey = $env:GROQ_API_KEY,
  [string]$GroqModel = "llama-3.1-8b-instant",
  [ValidateSet("apk", "run")]
  [string]$Target = "apk",
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-ApiKey {
  $secure = Read-Host "Enter GROQ API key (gsk_...)" -AsSecureString
  if ($null -eq $secure) {
    return ""
  }

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

if ([string]::IsNullOrWhiteSpace($GroqApiKey)) {
  $GroqApiKey = Read-ApiKey
}

if ([string]::IsNullOrWhiteSpace($GroqApiKey)) {
  throw "GROQ API key is required."
}

$scriptRoot = Split-Path -Parent $PSCommandPath
Push-Location $scriptRoot

try {
  $defines = @(
    "--dart-define=GROQ_API_KEY=$GroqApiKey"
    "--dart-define=GROQ_MODEL=$GroqModel"
  )

  if ($Target -eq "run") {
    Write-Host "Running app with Groq model: $GroqModel"
    if ($DryRun) {
      Write-Host "Dry run: flutter run <groq defines>"
      return
    }
    & flutter run @defines
  } else {
    Write-Host "Building release APK with Groq model: $GroqModel"
    if ($DryRun) {
      Write-Host "Dry run: flutter build apk --release <groq defines>"
      return
    }
    & flutter build apk --release @defines
  }

  if ($LASTEXITCODE -ne 0) {
    throw "Flutter command failed with exit code $LASTEXITCODE."
  }

  if ($Target -eq "apk") {
    $apkPath = Join-Path $scriptRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
      Write-Host "APK ready: $apkPath"
    }
  }
} finally {
  Pop-Location
}
