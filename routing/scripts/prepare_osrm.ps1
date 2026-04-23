param(
  [string]$SourcePbf = "../thailand_osm_data/thailand-260407.osm.pbf",
  [string]$Profile = "car",
  [string]$OsrmImage = "osrm/osrm-backend:latest",
  [string]$OsmiumImage = "iboates/osmium:latest",
  [switch]$SkipRegionBuild
)

$ErrorActionPreference = "Stop"

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-Checked([string]$Cmd, [string[]]$Args) {
  & $Cmd @Args
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed ($LASTEXITCODE): $Cmd $($Args -join ' ')"
  }
}

function Assert-File([string]$PathToCheck, [int64]$MinBytes = 1) {
  if (-not (Test-Path $PathToCheck)) {
    throw "Required file not found: $PathToCheck"
  }
  $f = Get-Item $PathToCheck
  if ($f.Length -lt $MinBytes) {
    throw "File is too small/corrupt: $PathToCheck ($($f.Length) bytes)"
  }
}

Assert-Command "docker"
Assert-Command "python"

Invoke-Checked "docker" @("version")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$routingRoot = Join-Path $repoRoot "routing"
$sourcePbfPath = Resolve-Path (Join-Path $routingRoot $SourcePbf)
Assert-File $sourcePbfPath 1048576

New-Item -ItemType Directory -Force (Join-Path $routingRoot "output\extracts") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $routingRoot "output\osrm\bangkok-metro") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $routingRoot "output\osrm\bangkok-perimeter") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $routingRoot "output\cache") | Out-Null

if (-not $SkipRegionBuild) {
  Write-Host "[1/6] Building region polygons ..."
  Invoke-Checked "python" @((Join-Path $routingRoot "scripts\build_th_bangkok_regions.py"))
}

$metroRegion = Join-Path $routingRoot "regions\bangkok-metro.geojson"
$periRegion = Join-Path $routingRoot "regions\bangkok-perimeter.geojson"
Assert-File $metroRegion 100
Assert-File $periRegion 100

$extractMetro = Join-Path $routingRoot "output\extracts\bangkok-metro.osm.pbf"
$extractPeri = Join-Path $routingRoot "output\extracts\bangkok-perimeter.osm.pbf"

Write-Host "[2/6] Extracting bangkok-metro from Thailand PBF ..."
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsmiumImage,"extract","-s","simple","-p","/data/routing/regions/bangkok-metro.geojson","-o","/data/routing/output/extracts/bangkok-metro.osm.pbf","/data/thailand_osm_data/thailand-260407.osm.pbf","--overwrite")
Assert-File $extractMetro 1048576

Write-Host "[3/6] Extracting bangkok-perimeter from Thailand PBF ..."
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsmiumImage,"extract","-s","simple","-p","/data/routing/regions/bangkok-perimeter.geojson","-o","/data/routing/output/extracts/bangkok-perimeter.osm.pbf","/data/thailand_osm_data/thailand-260407.osm.pbf","--overwrite")
Assert-File $extractPeri 1048576

Write-Host "[4/6] Preprocessing bangkok-metro (extract/partition/customize) ..."
$metroWorkPbf = Join-Path $routingRoot "output\osrm\bangkok-metro\bangkok-metro.osm.pbf"
Copy-Item $extractMetro $metroWorkPbf -Force
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsrmImage,"osrm-extract","-p","/opt/${Profile}.lua","/data/routing/output/osrm/bangkok-metro/bangkok-metro.osm.pbf")
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsrmImage,"osrm-partition","/data/routing/output/osrm/bangkok-metro/bangkok-metro.osrm")
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsrmImage,"osrm-customize","/data/routing/output/osrm/bangkok-metro/bangkok-metro.osrm")
Assert-File (Join-Path $routingRoot "output\osrm\bangkok-metro\bangkok-metro.osrm.mldgr") 1024

Write-Host "[5/6] Preprocessing bangkok-perimeter (extract/partition/customize) ..."
$periWorkPbf = Join-Path $routingRoot "output\osrm\bangkok-perimeter\bangkok-perimeter.osm.pbf"
Copy-Item $extractPeri $periWorkPbf -Force
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsrmImage,"osrm-extract","-p","/opt/${Profile}.lua","/data/routing/output/osrm/bangkok-perimeter/bangkok-perimeter.osm.pbf")
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsrmImage,"osrm-partition","/data/routing/output/osrm/bangkok-perimeter/bangkok-perimeter.osrm")
Invoke-Checked "docker" @("run","--rm","-v","${repoRoot}:/data",$OsrmImage,"osrm-customize","/data/routing/output/osrm/bangkok-perimeter/bangkok-perimeter.osrm")
Assert-File (Join-Path $routingRoot "output\osrm\bangkok-perimeter\bangkok-perimeter.osrm.mldgr") 1024

Write-Host "[6/6] Done. Start runtime services with: ./scripts/start_osrm.ps1"
