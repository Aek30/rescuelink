# RMUTT Khlong Hok offline map

`rmutt.json` is a vector extract bundled in the Flutter application, not a tile cache.
It contains roads, buildings, campus/land polygons and water from OpenStreetMap.
No map server, access token or first-run map download is required.

- Bounds (west, south, east, north): `100.719, 14.026, 100.738, 14.045`.
- Source retrieved 2026-10-18: https://api.openstreetmap.org/api/0.6/map?bbox=100.719,14.026,100.738,14.045
- Copyright: © OpenStreetMap contributors.
- Database license: Open Database License 1.0, https://opendatacommons.org/licenses/odbl/1-0/
- Attribution and rights: https://www.openstreetmap.org/copyright
- Derived extract is distributed under ODbL 1.0. Original OSM geometry is retained;
  unneeded metadata is omitted, and features are classified for rendering.
- `rmutt-source.osm` is the source extract for reproducibility; only `rmutt.json`
  is bundled by pubspec.yaml. Run `./tool/prepare_offline_map.ps1` to regenerate.

Map completeness reflects OSM at extraction time. It does not encode current
road closures, disaster conditions, safe routes, or offline routing.
