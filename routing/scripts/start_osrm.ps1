param(
  [switch]$Detached = $true
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
$compose = Join-Path $root "docker-compose.osrm.yml"

if (-not (Test-Path $compose)) {
  throw "Compose file not found: $compose"
}

$cmd = @("compose", "-f", $compose, "up")
if ($Detached) { $cmd += "-d" }
& docker @cmd

Write-Host "OSRM services are up:"
Write-Host "- bangkok-metro      => http://localhost:5400"
Write-Host "- bangkok-perimeter  => http://localhost:5401"