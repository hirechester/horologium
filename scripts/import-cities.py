#!/usr/bin/env python3
"""Convert GeoNames cities15000.zip and admin1CodesASCII.txt to our offline catalog.
Usage: python3 scripts/import-cities.py cities15000.zip admin1CodesASCII.txt
Sources: https://download.geonames.org/export/dump/ (CC BY 4.0).
"""
import json
import pathlib
import sys
import zipfile

regions = {}
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    fields = line.split('\t')
    if len(fields) >= 2:
        regions[fields[0]] = fields[1]
with zipfile.ZipFile(sys.argv[1]) as archive:
    lines = archive.read('cities15000.txt').decode().splitlines()
cities = []
for line in lines:
    f = line.split('\t')
    if len(f) < 19 or not f[17]:
        continue
    cities.append(dict(id=int(f[0]), name=f[1], region=regions.get(f'{f[8]}.{f[10]}', ''),
                       country=f[8], timeZoneID=f[17], population=int(f[14]), aliases=f[3]))
cities.sort(key=lambda c: c['id'])
output = pathlib.Path(__file__).resolve().parents[1] / 'Horologium/Resources/Cities.json'
output.write_text(json.dumps(cities, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'Wrote {len(cities):,} cities to {output}')
