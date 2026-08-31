#!/usr/bin/env bash
# Downloads input data: Plovdiv GTFS (BGNAP), the OSM extract, MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# The feed is published on the Bulgarian National Access Point (sipbg.gov.bg)
# and rebuilt every night, so its download link carries a fresh id each day.
# The id is resolved through the portal API instead of being hard-coded:
#   dataset -> subsets (format=gtfs-static) -> files (is_latest) -> /download
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm/tiles web/vendor

# pyosmium does the cutting; it is the one dependency outside Node here.
need_osmium () {
  python3 -c "import osmium" 2>/dev/null && return 0
  echo "brak pakietu osmium — zainstaluj: pip3 install --user osmium" >&2
  return 1
}

# 1) GTFS
NAP="https://sipbg.gov.bg/bgnap/portal/api/catalog"
DATASET="1bb57544-8bb4-4f77-8d65-5d31ffdee221"   # "Plovdiv transport data"

if [ ! -f data/gtfs/routes.txt ]; then
  echo "== BGNAP: resolving the latest GTFS file =="
  SUBSET=$(curl -fsS --max-time 60 "$NAP/datasets/$DATASET/subsets?locale=en" \
    | python3 -c 'import sys,json;print(next(s["id"] for s in json.load(sys.stdin) if s["format"]=="gtfs-static"))')
  FILE_ID=$(curl -fsS --max-time 60 "$NAP/subsets/$SUBSET/files?format=gtfs-static" \
    | python3 -c 'import sys,json
fs = json.load(sys.stdin)
if not fs: raise SystemExit("BGNAP lists no GTFS file for this dataset")
f = next((x for x in fs if x.get("is_latest")), fs[0])
print(f["id"], f["filename"], file=sys.stderr)
print(f["id"])')
  curl -fL --retry 3 --max-time 600 -o data/plovdiv-gtfs.zip "$NAP/files/$FILE_ID/download"
  unzip -o data/plovdiv-gtfs.zip -d data/gtfs
fi

# 2) OSM — from the Geofabrik extract, not Overpass.
#    Plovdiv is one 9 x 11 km tile; Overpass was answering 504 from every
#    mirror on the day this was built, so the tile comes out of the Bulgarian
#    Geofabrik extract instead.
#    pipeline/pbf-tiles.py cuts the tiles out of the .pbf and writes exactly the
#    JSON shape Overpass would have returned (ways with tags, NODE IDS and
#    geometry — buildGraph silently drops ways without el.nodes).
if [ ! -f data/osm/tiles/t1.json ]; then
  need_osmium
  if [ ! -f data/bulgaria-latest.osm.pbf ]; then
    echo "== Geofabrik bulgaria-latest.osm.pbf =="
    curl -fL --retry 5 --retry-delay 5 -C - --max-time 3600 -o data/bulgaria-latest.osm.pbf \
      "https://download.geofabrik.de/europe/bulgaria-latest.osm.pbf"
  fi
  echo "== cutting OSM tiles out of the extract =="
  python3 pipeline/pbf-tiles.py
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/gtfs data/osm 2>/dev/null || true
