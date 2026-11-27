param(
  [Parameter(Mandatory=$true)][string]$SetupPath,
  [Parameter(Mandatory=$true)][string]$PayloadPath
)
$ErrorActionPreference = 'Stop'
$setup = (Resolve-Path $SetupPath).Path
$payload = (Resolve-Path $PayloadPath).Path
$root = Join-Path $env:RUNNER_TEMP ("diaspro-smoke-" + [guid]::NewGuid())
$install = Join-Path $root "app"
$sentinel = Join-Path $root "document.md"
New-Item -ItemType Directory -Path $root | Out-Null
Set-Content -Path $sentinel -Value "# User document"
$before = (Get-FileHash $sentinel).Hash
$progId = "dev.diaspro.markdown.document"
$registry = "HKCU:\Software\Classes"
$uninstaller = Join-Path $install "unins000.exe"
$classes = 'Registry::HKEY_CLASSES_ROOT'
$extensions = @('.md', '.markdown')
$prior = @{}
foreach ($extension in $extensions) {
  $item = Get-Item (Join-Path $classes $extension) -ErrorAction SilentlyContinue
  $prior[$extension] = if ($item) { $item.GetValue('') } else { $null }
}
$newPath = Join-Path $registry '.md\ShellNew'
$priorNew = Test-Path (Join-Path $classes '.md\ShellNew')
$priorMarkdownNew = Test-Path (Join-Path $classes '.markdown\ShellNew')
try {
  $process = Start-Process -FilePath $setup -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART","/SP-",('/DIR="' + $install + '"'),('/LOG="' + (Join-Path $root 'install.log') + '"') -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "Installer exit code $($process.ExitCode)" }
  $exe = Join-Path $install "Diaspro Markdown.exe"
  if (!(Test-Path $exe) -or !(Test-Path $uninstaller)) { throw "Installed executable or uninstaller missing" }
  if ((Get-FileHash $exe).Hash -ne (Get-FileHash $payload).Hash) { throw "Installed executable differs from build payload" }
  foreach ($extension in $extensions) {
    $openWith = Get-Item (Join-Path $registry "$extension\OpenWithProgids")
    if ($openWith.GetValueNames() -notcontains $progId) { throw "Missing OpenWith registration: $extension" }
    $expected = if ($null -eq $prior[$extension]) { $progId } else { $prior[$extension] }
    if ((Get-Item (Join-Path $classes $extension)).GetValue('') -ne $expected) { throw "Default editor not preserved: $extension" }
  }
  if (!$priorNew) {
    $key = Get-Item $newPath
    if ($key.GetValueNames() -notcontains 'NullFile' -or $key.GetValue('NullFile') -ne '') { throw 'ShellNew NullFile missing' }
    if ($key.GetValue('DiasproOwner') -ne $progId) { throw 'ShellNew owner missing' }
  }
  if (!$priorMarkdownNew -and (Test-Path (Join-Path $classes '.markdown\ShellNew'))) { throw 'ShellNew must only apply to .md' }
  $command = (Get-Item (Join-Path $registry "$progId\shell\open\command")).GetValue("")
  if ($command -ne ('"' + $exe + '" "%1"')) { throw "Invalid file-open command: $command" }
  $process = Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "Uninstaller exit code $($process.ExitCode)" }
  if (Test-Path $exe) { throw "Executable remains after uninstall" }
  if (Test-Path (Join-Path $registry $progId)) { throw "ProgID remains after uninstall" }
  if (!$priorNew -and (Test-Path $newPath)) { throw 'Owned ShellNew remains after uninstall' }
  foreach ($extension in $extensions) {
    $openWith = Get-Item (Join-Path $registry "$extension\OpenWithProgids") -ErrorAction SilentlyContinue
    if ($openWith -and $openWith.GetValueNames() -contains $progId) { throw "OpenWith remains: $extension" }
    $item = Get-Item (Join-Path $classes $extension) -ErrorAction SilentlyContinue
    $actual = if ($item) { $item.GetValue('') } else { $null }
    if ($actual -ne $prior[$extension]) { throw "Default editor changed after uninstall: $extension" }
  }
  if ((Get-FileHash $sentinel).Hash -ne $before) { throw "User document changed" }
  Write-Host "Clean install, associations, payload and uninstall verified."
} finally {
  if (Test-Path $uninstaller) {
    Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait | Out-Null
  }
}
