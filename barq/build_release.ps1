[CmdletBinding()]
param(
  [string]$GroqApiKey = $env:GROQ_API_KEY,
  [string]$GroqModel = "llama-3.1-8b-instant",
  [string]$GeminiApiKey = $env:GEMINI_API_KEY,
  [string]$GeminiModel = "gemini-2.5-flash",
  [ValidateSet("apk", "run")]
  [string]$Target = "apk",
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Secret([string]$prompt) {
  $secure = Read-Host $prompt -AsSecureString
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

if ([string]::IsNullOrWhiteSpace($GeminiApiKey)) {
  $GeminiApiKey = Read-Secret "Enter Gemini API key (AIza...)"
}

if ([string]::IsNullOrWhiteSpace($GeminiApiKey) -and [string]::IsNullOrWhiteSpace($GroqApiKey)) {
  $GroqApiKey = Read-Secret "Enter GROQ API key (gsk_...) or blank to skip"
}

if ([string]::IsNullOrWhiteSpace($GeminiApiKey) -and [string]::IsNullOrWhiteSpace($GroqApiKey)) {
  throw "Need at least one of: Gemini key or Groq key."
}

$scriptRoot = Split-Path -Parent $PSCommandPath
Push-Location $scriptRoot

try {
  $defines = @()

  if (-not [string]::IsNullOrWhiteSpace($GeminiApiKey)) {
    $defines += "--dart-define=GEMINI_API_KEY=$GeminiApiKey"
    $defines += "--dart-define=GEMINI_MODEL=$GeminiModel"
  }

  if (-not [string]::IsNullOrWhiteSpace($GroqApiKey)) {
    $defines += "--dart-define=GROQ_API_KEY=$GroqApiKey"
    $defines += "--dart-define=GROQ_MODEL=$GroqModel"
  }

  $providers = @()
  if (-not [string]::IsNullOrWhiteSpace($GeminiApiKey)) { $providers += "Gemini=$GeminiModel" }
  if (-not [string]::IsNullOrWhiteSpace($GroqApiKey)) { $providers += "Groq=$GroqModel" }
  $providerList = ($providers -join ", ")

  if ($Target -eq "run") {
    Write-Host "Running app with: $providerList"
    if ($DryRun) {
      Write-Host "Dry run: flutter run <defines>"
      return
    }
    & flutter run @defines
  } else {
    Write-Host "Building release APK with: $providerList"
    if ($DryRun) {
      Write-Host "Dry run: flutter build apk --release <defines>"
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
