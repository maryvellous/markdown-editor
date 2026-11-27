# Run locally, outside CI. Never copy keystore/passwords into the repository.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Keystore,
  [string]$Alias = 'diaspro-markdown',
  [switch]$CreateNew,
  [switch]$AllowNewIdentity,
  [switch]$ConfigureGitHub
)
$ErrorActionPreference = 'Stop'
$repo = 'maryvellous/markdown-editor'
$oldFingerprint = 'ba518176666a73cd2deed9a053ec22ba2913599fa5e7a9d50600a4abb0a3e747'
if ($env:GITHUB_ACTIONS -eq 'true') { throw 'Run on the owner-controlled computer, not CI.' }
$null = Get-Command keytool -ErrorAction Stop
$Keystore = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Keystore)
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
  $parent = Split-Path -Parent $Keystore
  while ($parent -and !(Test-Path -LiteralPath $parent)) { $parent = Split-Path -Parent $parent }
  if ($parent) {
    $inside = & git -C $parent rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $inside -eq 'true') { throw 'Keystore must be outside any Git working tree.' }
  }
}
if ($CreateNew -and (Test-Path -LiteralPath $Keystore)) { throw 'Refusing to overwrite an existing keystore.' }
if ($CreateNew -and !$AllowNewIdentity) { throw 'New key requires explicit -AllowNewIdentity.' }
if (!$CreateNew -and !(Test-Path -LiteralPath $Keystore -PathType Leaf)) { throw 'Keystore not found.' }
if ($ConfigureGitHub) {
  $null = Get-Command gh -ErrorAction Stop
  & gh auth status
  if ($LASTEXITCODE -ne 0) { throw 'Authenticate GitHub CLI first.' }
  $secrets = & gh secret list --repo $repo --json name
  if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing repository secrets.' }
  $vars = & gh variable list --repo $repo --json name
  if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing repository variables.' }
  $names = @($secrets | ConvertFrom-Json | ForEach-Object { $_.name })
  $varNames = @($vars | ConvertFrom-Json | ForEach-Object { $_.name })
  if (@($names | Where-Object { $_ -in @('ANDROID_RELEASE_KEYSTORE_B64','ANDROID_RELEASE_STORE_PASSWORD','ANDROID_RELEASE_KEY_PASSWORD','ANDROID_RELEASE_KEY_ALIAS') }).Count -or 'ANDROID_RELEASE_CERT_SHA256' -in $varNames) {
    throw 'Signing configuration already exists (or is partial). Do not overwrite it blindly; inspect and reconcile first.'
  }
}
function Read-PrivateValue([string]$Prompt) {
  $secure = Read-Host $Prompt -AsSecureString
  try { return [System.Net.NetworkCredential]::new('', $secure).Password }
  finally { $secure.Dispose() }
}
function Set-RepoSecret([string]$Name,[string]$Value) {
  $Value | & gh secret set $Name --repo $repo
  if ($LASTEXITCODE -ne 0) { throw "Failed to configure $Name. Keep the local key and reconcile partial settings before retrying." }
}
$cert = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.der')
try {
  $env:DIASPRO_LOCAL_STORE_PASS = Read-PrivateValue 'Keystore password'
  if ($CreateNew) {
    if ($env:DIASPRO_LOCAL_STORE_PASS.Length -lt 16) { throw 'Use a unique password of at least 16 characters.' }
    $confirm = Read-PrivateValue 'Repeat keystore password'
    if ($confirm -cne $env:DIASPRO_LOCAL_STORE_PASS) { throw 'Passwords differ.' }
    $confirm = $null
    $env:DIASPRO_LOCAL_KEY_PASS = $env:DIASPRO_LOCAL_STORE_PASS
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Keystore) | Out-Null
    & keytool -genkeypair -keystore $Keystore -storetype PKCS12 -alias $Alias -keyalg RSA -keysize 3072 -validity 18250 -dname 'CN=Diaspro Markdown, O=Diaspro, C=IT' -storepass:env DIASPRO_LOCAL_STORE_PASS -keypass:env DIASPRO_LOCAL_KEY_PASS
    if ($LASTEXITCODE -ne 0) { throw 'Key generation failed.' }
  } else {
    $env:DIASPRO_LOCAL_KEY_PASS = if ($ConfigureGitHub) { Read-PrivateValue 'Private key password' } else { $env:DIASPRO_LOCAL_STORE_PASS }
  }
  & keytool -exportcert -keystore $Keystore -alias $Alias -storepass:env DIASPRO_LOCAL_STORE_PASS -file $cert
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read certificate.' }
  $fingerprint = (Get-FileHash -Algorithm SHA256 -LiteralPath $cert).Hash.ToLowerInvariant()
  Write-Host "Certificate SHA-256: $fingerprint"
  if ($fingerprint -eq $oldFingerprint) { Write-Host 'Matches published Android 1.1.1 certificate.' }
  else {
    Write-Warning 'Different certificate: old installations cannot normally update in place.'
    if (!$AllowNewIdentity -and $ConfigureGitHub) { throw 'Use -AllowNewIdentity only after authorizing migration.' }
  }
  if (!$ConfigureGitHub) { return }
  if ((Read-Host 'Confirm encrypted offline backup of keystore and passwords exists: type BACKUP') -cne 'BACKUP') { throw 'Backup not confirmed; nothing uploaded.' }
  Set-RepoSecret 'ANDROID_RELEASE_KEYSTORE_B64' ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Keystore)))
  Set-RepoSecret 'ANDROID_RELEASE_STORE_PASSWORD' $env:DIASPRO_LOCAL_STORE_PASS
  Set-RepoSecret 'ANDROID_RELEASE_KEY_PASSWORD' $env:DIASPRO_LOCAL_KEY_PASS
  Set-RepoSecret 'ANDROID_RELEASE_KEY_ALIAS' $Alias
  & gh variable set ANDROID_RELEASE_CERT_SHA256 --repo $repo --body $fingerprint
  if ($LASTEXITCODE -ne 0) { throw 'Cannot configure expected certificate. Reconcile partial configuration before retrying.' }
  Write-Host 'Signing configuration installed. Run Build Android APK manually on main with sign_candidate enabled. No release was published.'
} finally {
  Remove-Item Env:DIASPRO_LOCAL_STORE_PASS, Env:DIASPRO_LOCAL_KEY_PASS -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $cert -ErrorAction SilentlyContinue
}
