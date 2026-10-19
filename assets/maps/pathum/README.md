# Pathum Thani offline vector database

© OpenStreetMap contributors. This derived database is distributed under
Open Database License 1.0: https://opendatacommons.org/licenses/odbl/1-0/
Attribution: https://www.openstreetmap.org/copyright

Source: https://download.geofabrik.de/asia/thailand-latest.osm.pbf
OSM snapshot: 2026-10-17T20:20:51Z. Extracted 2026-10-19.
Boundary: https://www.openstreetmap.org/relation/1908797 (via Nominatim).

The source is clipped to the province, simplified at four levels, clipped into
grid cells, and quantized to integer coordinates 0..4096 inside each tile.
Polygon holes are preserved. The app includes index.json and the tile JSONs;
it never downloads map tiles at runtime. index.json records provenance, bounds,
coverage geometry, source counts, level sizes and per-tile integrity statistics.

Regenerate with tool/prepare_pathum_map.py using osmium + shapely and the source
PBF/boundary downloads in tmp/pathum-map. The country PBF is not distributed in
the application. OSM completeness varies; this is not a live road-closure or
safe-routing database.
