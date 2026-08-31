# Plovdiv Public Transport — interactive map

Interactive, poster-grade map of the whole public transport network of
**Plovdiv**: 29 bus lines drawn along the real street geometry — 472 stops,
992 km, weighted mean matching error 1.87 m.

## Live

Local build on port 8166 (`npm run serve`).

Everything comes from ONE feed, published on the **Bulgarian National Access
Point** (sipbg.gov.bg) and rebuilt every night. Its download link carries a
fresh id each day, so `download.sh` resolves it through the portal API rather
than hard-coding it — dataset → subsets (`format=gtfs-static`) → files
(`is_latest`) → `/download`, the same dance sofia-bus-map does.

| mode | route_type | graph |
|---|---|---|
| buses | 3 | OSM roadways |

This is the family's plainest map: one mode, one colour, one graph. Plovdiv
has no tram and no metro, and its trolleybuses were withdrawn in 2012.

Four private operators share the network — Меритранс, Автобусни превози
Пловдив, Меритранс 2017 and КЗТ-Златанови — but they run one municipal
numbering, so nothing needs an operator mark. The feed carries no
`direction_id` at all, which the engine already expects: where direction_id
cannot separate directions it keys them by headsign, and this feed fills
headsigns on every trip.

Of 528 stop names only seventeen shout, and every one is an acronym the city
itself shouts (ДКЦ, ПГЕЕ, МОЛ 1), so nothing was rewritten.

## Pipeline

`npm run download` fetches the feed and cuts the OSM extract. **The OSM
data comes from Geofabrik, not Overpass** — the public mirrors were answering
504 to every request on the day this map was built, even for a single small
city box — so `pipeline/pbf-tiles.py` (needs `pip3 install --user osmium`)
clips the tiles out of `bulgaria-latest.osm.pbf`, writing exactly the JSON shape Overpass would
have returned, node ids included.

`npm run build` map-matches every line (HMM/Viterbi on the OSM graph) and
writes GeoJSON to `data/out/`; `npm run lines` adds the line-by-line view.
`npm run serve` hosts the map at <http://localhost:8166>.

Data: Bulgarian National Access Point (sipbg.gov.bg) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
