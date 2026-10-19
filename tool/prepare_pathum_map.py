"""Build bounded, multiresolution offline vector tiles from a Geofabrik PBF.

Run with osmium and shapely installed. Source downloads are build-time only.
The output is a derivative OSM database under ODbL 1.0.
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path

import osmium
from shapely import from_wkb, make_valid
from shapely.geometry import shape, box, LineString, Point, mapping
from shapely.prepared import prep


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pbf', default='tmp/pathum-map/thailand.osm.pbf')
    parser.add_argument('--boundary', default='tmp/pathum-map/province.json')
    parser.add_argument('--output', default='assets/maps/pathum')
    args = parser.parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    boundary_source = json.loads(Path(args.boundary).read_text(encoding='utf-8-sig'))[0]
    assert boundary_source['osm_id'] == 1908797, 'Not the Pathum Thani province boundary'
    boundary = make_valid(shape(boundary_source['geojson']))
    west, south, east, north = boundary.bounds
    prepared = prep(boundary)
    source_cache = Path(args.pbf).with_suffix('.pathum-features.json')
    source_counts = collections.Counter()
    features = []

    if source_cache.exists():
        for f in json.loads(source_cache.read_text(encoding='utf-8')):
            f['geom'] = shape(f['geom'])
            features.append(f)
            source_counts[f['kind']] += 1
    else:
        factory = osmium.geom.WKBFactory()
        processor = osmium.FileProcessor(args.pbf).with_locations().with_areas()
        processor.with_filter(osmium.filter.KeyFilter('highway', 'building', 'landuse',
            'natural', 'waterway', 'leisure', 'amenity', 'place'))
        for obj in processor:
            tags = dict(obj.tags)
            kind = None
            geom = None
            if obj.is_node():
                if tags.get('place') not in ('city', 'town', 'village', 'suburb', 'hamlet'): continue
                if not (west <= obj.lon <= east and south <= obj.lat <= north): continue
                kind, geom = 'place', Point(obj.lon, obj.lat)
            elif obj.is_way():
                if 'highway' in tags and tags['highway'] not in ('proposed', 'construction'):
                    kind = 'road'
                elif 'waterway' in tags and not obj.is_closed():
                    kind = 'water'
                else: continue
                coords = [(n.lon, n.lat) for n in obj.nodes if n.location.valid()]
                if len(coords) < 2: continue
                xs, ys = zip(*coords)
                if max(xs) < west or min(xs) > east or max(ys) < south or min(ys) > north: continue
                geom = LineString(coords)
            elif obj.is_area():
                if 'building' in tags: kind = 'building'
                elif tags.get('natural') == 'water' or 'waterway' in tags: kind = 'water'
                elif tags.get('amenity') == 'university': kind = 'campus'
                elif 'landuse' in tags or 'leisure' in tags: kind = 'land'
                else: continue
                # Avoid constructing geometry for millions of distant buildings.
                rings = list(obj.outer_rings())
                if not any(west <= n.lon <= east and south <= n.lat <= north
                           for ring in rings for n in ring if n.location.valid()): continue
                try: geom = from_wkb(factory.create_multipolygon(obj))
                except Exception: continue
            else: continue
            if not geom.is_valid: geom = make_valid(geom)
            if not prepared.intersects(geom): continue
            geom = geom.intersection(boundary)
            if geom.is_empty: continue
            name = tags.get('name:th', tags.get('name', ''))
            if not name and kind == 'road': name = tags.get('ref', '')
            features.append({'id': f'{obj.type_str()}{obj.id}', 'kind': kind,
                'name': name, 'roadClass': tags.get('highway', ''), 'geom': geom})
            source_counts[kind] += 1
        dump(source_cache, [{**f, 'geom': mapping(f['geom'])} for f in features])
    print('Provincial source features:', dict(source_counts), flush=True)

    manifest = {'version': 2, 'name': 'จังหวัดปทุมธานี', 'extractedAt': '2026-10-19',
        'bounds': [west, south, east, north], 'boundary': mapping(boundary),
        'source': 'https://download.geofabrik.de/asia/thailand-latest.osm.pbf',
        'boundarySource': 'https://www.openstreetmap.org/relation/1908797',
        'attribution': '© OpenStreetMap contributors • ODbL 1.0',
        'license': 'https://opendatacommons.org/licenses/odbl/1-0/',
        'sourceCounts': dict(source_counts), 'levels': [1, 4, 16, 64], 'tiles': {}}
    major = {'motorway','motorway_link','trunk','trunk_link','primary','primary_link',
             'secondary','secondary_link','tertiary','tertiary_link'}

    def parts(geometry):
        if geometry.geom_type in ('Polygon', 'LineString', 'Point'):
            yield geometry
        elif hasattr(geometry, 'geoms'):
            for child in geometry.geoms: yield from parts(child)

    total_bytes = 0
    for level, count in enumerate(manifest['levels']):
        tiles = collections.defaultdict(list)
        tile_width, tile_height = (east-west)/count, (north-south)/count
        tolerance = [0.00015, 0.000035, 0.000008, 0.000002][level]
        for f in features:
            kind, geom = f['kind'], f['geom']
            if level == 0 and (kind == 'building' or
                kind == 'road' and f['roadClass'] not in major or
                kind in ('land','campus') and geom.area < .00015): continue
            if level == 1 and (kind == 'building' or
                kind == 'road' and f['roadClass'] not in major and
                    (f['roadClass'] not in ('residential','unclassified') or geom.length < .0008) or
                kind in ('land','campus') and geom.area < .000015): continue
            if level < 2 and kind == 'water' and geom.area < .000003 and geom.length < .002: continue
            if level == 2 and kind == 'building' and geom.area < .00000008: continue
            geom = geom.simplify(tolerance, preserve_topology=True)
            a,b,c,d = geom.bounds
            x0,x1 = max(0,int((a-west)/tile_width)), min(count-1,int((c-west)/tile_width))
            y0,y1 = max(0,int((north-d)/tile_height)), min(count-1,int((north-b)/tile_height))
            anchor = geom.representative_point()
            for x in range(x0,x1+1):
                for y in range(y0,y1+1):
                    left, top = west+x*tile_width, north-y*tile_height
                    clip = box(left, top-tile_height, left+tile_width, top)
                    if not geom.intersects(clip): continue
                    def packed(coords):
                        result = []
                        for lon,lat in coords:
                            result.extend([round((lon-left)/tile_width*4096), round((top-lat)/tile_height*4096)])
                        return result
                    for part in parts(geom.intersection(clip)):
                        if part.is_empty: continue
                        paths = []
                        closed = part.geom_type == 'Polygon'
                        if closed:
                            paths = [packed(part.exterior.coords), *[packed(r.coords) for r in part.interiors]]
                        elif part.geom_type == 'LineString': paths = [packed(part.coords)]
                        label = packed([(anchor.x,anchor.y)]) if clip.covers(anchor) else None
                        tiles[x,y].append({'k':kind,'r':f['roadClass'],'p':paths,'c':closed,
                            'n':f['name'] if label else '', 'a':label})
        for (x,y), tile in tiles.items():
            key = f'{level}_{x}_{y}'
            dest = output / f'{key}.json'
            dump(dest,tile)
            vertices = sum(sum(len(p)//2 for p in f['p']) for f in tile)
            manifest['tiles'][key] = {'bytes':dest.stat().st_size,'vertices':vertices,'features':len(tile)}
            total_bytes += dest.stat().st_size
        print(f'Level {level}: {len(tiles)} tiles', flush=True)
    manifest['tileBytes'] = total_bytes
    with osmium.io.Reader(args.pbf) as reader:
        manifest['osmTimestamp'] = reader.header().get('osmosis_replication_timestamp')
    dump(output/'index.json',manifest)
    print(f'Total {len(manifest["tiles"])} tiles, {total_bytes/1024/1024:.2f} MiB', flush=True)


if __name__ == '__main__': main()
