# OSRM Routing Pipeline (Bangkok + Perimeter)

This package builds high-performance routing datasets from `thailand-260407.osm.pbf` and runs OSRM in Docker.

## Regions
- `bangkok-metro`: Bangkok + perimeter provinces.
- `bangkok-perimeter`: Nonthaburi, Pathum Thani, Samut Prakan, Samut Sakhon, Nakhon Pathom.

## Requirements
- Docker Engine + Docker Compose
- Python 3.10+

## Notes
- Region extraction uses `osmium extract -s simple` to reduce memory pressure on large Thailand PBF inputs.

## Quick Start
```powershell
cd routing
./scripts/prepare_osrm.ps1
./scripts/start_osrm.ps1
./scripts/smoke_test.ps1
```

## Output Structure
- `routing/regions/*.geojson` generated boundary polygons
- `routing/output/extracts/*.osm.pbf` extracted OSM regions
- `routing/output/osrm/<region>/...` OSRM MLD artifacts

## Runtime Endpoints
- `http://localhost:5400` => `bangkok-metro`
- `http://localhost:5401` => `bangkok-perimeter`

## Example Route Query
```text
/route/v1/driving/100.5018,13.7563;100.5410,13.7360?overview=false&annotations=distance,duration
```
