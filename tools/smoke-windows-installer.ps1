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
try {
  $process = Start-Process -FilePath $setup -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART","/SP-",('/DIR="' + $install + '"'),('/LOG="' + (Join-Path $root 'install.log') + '"') -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "Installer exit code $($process.ExitCode)" }
  $exe = Join-Path $install "Diaspro Markdown.exe"
  if (!(Test-Path $exe) -or !(Test-Path $uninstaller)) { throw "Installed executable or uninstaller missing" }
  if ((Get-FileHash $exe).Hash -ne (Get-FileHash $payload).Hash) { throw "Installed executable differs from build payload" }
  foreach ($extension in @(".md", ".markdown")) {
    if ((Get-Item (Join-Path $registry $extension)).GetValue("") -ne $progId) { throw "Missing association: $extension" }
  }
  $command = (Get-Item (Join-Path $registry "$progId\shell\open\command")).GetValue("")
  if ($command -ne ('"' + $exe + '" "%1"')) { throw "Invalid file-open command: $command" }
  $process = Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "Uninstaller exit code $($process.ExitCode)" }
  if (Test-Path $exe) { throw "Executable remains after uninstall" }
  if (Test-Path (Join-Path $registry $progId)) { throw "ProgID remains after uninstall" }
  if ((Get-FileHash $sentinel).Hash -ne $before) { throw "User document changed" }
  Write-Host "Clean install, associations, payload and uninstall verified."
} finally {
  if (Test-Path $uninstaller) {
    Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait | Out-Null
  }
}
