# ai-pid1 Windows bootstrap: installs/uses WSL Ubuntu, then runs Linux bootstrap inside WSL.
# Run from PowerShell as Administrator for first-time WSL install:
#   irm https://raw.githubusercontent.com/salus-ryan/ai-pid1/master/bootstrap-windows.ps1 | iex
$ErrorActionPreference = "Stop"
function Say($m){ Write-Host "[ai-pid1/windows] $m" }
function Has($c){ $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
$Distro = $env:AI_PID1_WSL_DISTRO; if(!$Distro){ $Distro="Ubuntu" }
$Repo = "https://raw.githubusercontent.com/salus-ryan/ai-pid1/master/bootstrap.sh"
if(!(Has wsl)){
  Say "WSL not found. Installing WSL + $Distro. This may require reboot."
  wsl --install -d $Distro
  Say "If Windows asked for reboot, reboot, open Ubuntu once, then rerun this script."
  exit 0
}
$distros = (wsl -l -q) -join "`n"
if($distros -notmatch [regex]::Escape($Distro)){
  Say "Installing WSL distro: $Distro"
  wsl --install -d $Distro
  Say "If install requested setup/reboot, finish it, then rerun this script."
  exit 0
}
Say "Running ai-pid1 Linux bootstrap inside WSL distro: $Distro"
wsl -d $Distro -- bash -lc "set -e; if command -v curl >/dev/null 2>&1; then curl -fsSL $Repo | sh; else wget -qO- $Repo | sh; fi"
Say "Done. In WSL, project is usually at: ~/ai-pid1"
