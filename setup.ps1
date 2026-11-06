# One-time setup on Windows: checks Python, installs pandas, makes a desktop shortcut.
# Run from this folder with:  powershell -ExecutionPolicy Bypass -File setup.ps1
Set-Location $PSScriptRoot
Write-Host "Network Compass setup"

$python = $null
foreach ($candidate in @("python", "py")) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found -and $found.Source -notlike "*WindowsApps*") { $python = $candidate; break }
}
if (-not $python) {
    Write-Host "Python is missing. Install it from python.org/downloads."
    Write-Host "In the installer, tick 'Add python.exe to PATH'. Then open a new window and run this again."
    exit 1
}
& $python -c "import sys; sys.exit(sys.version_info < (3, 9))"
if ($LASTEXITCODE -ne 0) { Write-Host "Python 3.9 or newer is needed. Get it from python.org/downloads."; exit 1 }
Write-Host "OK   $(& $python --version)"

& $python -c "import pandas" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "...  Installing pandas"
    & $python -m pip install --user --quiet pandas
    if ($LASTEXITCODE -ne 0) { Write-Host "Could not install pandas. Check your internet connection and run this again."; exit 1 }
}
Write-Host "OK   pandas"

New-Item -ItemType Directory -Force -Path export | Out-Null
& $python -m unittest discover -s tests 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "The self-test failed. Open Claude Code in this folder and ask it to run: python -m unittest discover -s tests"
    exit 1
}
Write-Host "OK   Self-test on made-up data"

$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Network Compass.lnk")
$shortcut.TargetPath = Join-Path $PSScriptRoot "Network Compass.bat"
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Save()
Write-Host "OK   Desktop shortcut"
Write-Host ""
Write-Host "All set. Next: type  claude  and then  /setup-network"
