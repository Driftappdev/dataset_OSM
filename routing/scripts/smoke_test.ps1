$ErrorActionPreference = "Stop"

$routeMetro = "http://127.0.0.1:5400/route/v1/driving/100.5018,13.7563;100.5410,13.7360?overview=false&annotations=distance,duration"
$routePeri  = "http://127.0.0.1:5401/route/v1/driving/100.913949,13.946435;100.851021,13.939235?overview=false&annotations=distance,duration"

for ($i = 0; $i -lt 20; $i++) {
  try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:5400/nearest/v1/driving/100.5018,13.7563" -TimeoutSec 3
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:5401/nearest/v1/driving/100.913949,13.946435" -TimeoutSec 3
    break
  } catch {
    Start-Sleep -Seconds 2
  }
}

$metro = Invoke-RestMethod -Uri $routeMetro -TimeoutSec 15
$peri  = Invoke-RestMethod -Uri $routePeri -TimeoutSec 15

[pscustomobject]@{
  metro_code = $metro.code
  metro_distance_m = $metro.routes[0].distance
  metro_duration_s = $metro.routes[0].duration
  perimeter_code = $peri.code
  perimeter_distance_m = $peri.routes[0].distance
  perimeter_duration_s = $peri.routes[0].duration
} | Format-List
