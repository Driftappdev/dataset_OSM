"""
Build Bangkok region polygons for OSM extraction.
Generates:
- routing/regions/bangkok-metro.geojson
- routing/regions/bangkok-perimeter.geojson
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.request
from pathlib import Path

API_URL = "https://www.geoboundaries.org/api/current/gbOpen/THA/ADM1/"
DEFAULT_DIRECT = "https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/THA/ADM1/geoBoundaries-THA-ADM1.geojson"

METRO_PROVINCES = {
    "bangkok",
    "nonthaburi",
    "pathum thani",
    "samut prakan",
    "samut sakhon",
    "nakhon pathom",
}

PERIMETER_PROVINCES = METRO_PROVINCES - {"bangkok"}


def norm(text: str) -> str:
    value = text.strip().lower()
    value = re.sub(r"\s+province$", "", value)
    value = value.replace("_", " ").replace("-", " ")
    value = re.sub(r"\s+", " ", value)
    alias = {
        "krung thep maha nakhon": "bangkok",
        "pathumthani": "pathum thani",
        "samutprakan": "samut prakan",
        "samutsakhon": "samut sakhon",
        "nakhonpathom": "nakhon pathom",
    }
    return alias.get(value, value)


def extract_name(properties: dict) -> str:
    keys = ["shapeName", "shapeNameTh", "NAME_1", "name", "province", "prov_name", "ADM1_EN"]
    for key in keys:
        if key in properties and str(properties[key]).strip():
            return str(properties[key]).strip()
    return ""


def fetch_geojson(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=120) as resp:
        return json.loads(resp.read().decode("utf-8"))


def resolve_geojson_url() -> str:
    data = fetch_geojson(API_URL)
    url = data.get("simplifiedGeometryGeoJSON") or data.get("gjDownloadURL")
    if isinstance(url, str) and url.strip():
        return url.strip()
    return DEFAULT_DIRECT


def load_features(cache_file: Path) -> list[dict]:
    if cache_file.exists():
        obj = json.loads(cache_file.read_text(encoding="utf-8"))
        return obj.get("features", [])

    direct_url = resolve_geojson_url()
    obj = fetch_geojson(direct_url)
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
    return obj.get("features", [])


def geometry_to_multipolygon(geometries: list[dict]) -> dict:
    multipolygon_coords = []
    for geom in geometries:
        gtype = geom.get("type")
        coords = geom.get("coordinates")
        if gtype == "Polygon":
            multipolygon_coords.append(coords)
        elif gtype == "MultiPolygon":
            multipolygon_coords.extend(coords)
    return {"type": "MultiPolygon", "coordinates": multipolygon_coords}


def write_region(path: Path, region_name: str, geoms: list[dict], provinces: list[str]) -> None:
    _ = region_name
    _ = provinces
    # osmium extract expects a Polygon/MultiPolygon geometry object.
    payload = geometry_to_multipolygon(geoms)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="routing/regions")
    parser.add_argument("--cache-file", default="routing/output/cache/th_adm1.geojson")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    cache_file = Path(args.cache_file)

    features = load_features(cache_file)

    metro_geoms = []
    perimeter_geoms = []
    metro_names = []
    perimeter_names = []

    for feat in features:
        props = feat.get("properties") or {}
        geom = feat.get("geometry") or {}
        province_raw = extract_name(props)
        province = norm(province_raw)
        if not geom:
            continue

        if province in METRO_PROVINCES:
            metro_geoms.append(geom)
            metro_names.append(province_raw)
        if province in PERIMETER_PROVINCES:
            perimeter_geoms.append(geom)
            perimeter_names.append(province_raw)

    if not metro_geoms:
        raise RuntimeError("No Bangkok-metro geometries found.")
    if not perimeter_geoms:
        raise RuntimeError("No Bangkok-perimeter geometries found.")

    write_region(out_dir / "bangkok-metro.geojson", "bangkok-metro", metro_geoms, sorted(set(metro_names)))
    write_region(out_dir / "bangkok-perimeter.geojson", "bangkok-perimeter", perimeter_geoms, sorted(set(perimeter_names)))

    print("Generated regions:")
    print("-", out_dir / "bangkok-metro.geojson")
    print("-", out_dir / "bangkok-perimeter.geojson")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
