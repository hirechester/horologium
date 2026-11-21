#!/usr/bin/env python3
"""Import fully-qualified Unicode emoji with searchable names and categories.
Usage: python3 scripts/import-emoji.py emoji-test.txt en.xml
Keywords: unicode-org/cldr release-46/common/annotations/en.xml
Pinned source: https://unicode.org/Public/emoji/16.0/emoji-test.txt
Unicode 16 is supported by Horologium's minimum macOS version.
"""
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
keywords = {}
if len(sys.argv) > 2:
    for annotation in ET.parse(sys.argv[2]).iter('annotation'):
        glyph = annotation.attrib.get('cp', '').replace('\ufe0f', '')
        keywords.setdefault(glyph, []).append(annotation.text or '')
entries = []
group = subgroup = ''
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if line.startswith('# group: '):
        group = line.removeprefix('# group: ')
    if line.startswith('# subgroup: '):
        subgroup = line.removeprefix('# subgroup: ')
    match = re.match(r'^([0-9A-F ]+)\s*; fully-qualified\s*# (\S+) E[\d.]+ (.+)$', line)
    if not match:
        continue
    points, glyph, name = match.groups()
    aliases = keywords.get(glyph.replace('\ufe0f', ''), []).copy()
    if subgroup == 'country-flag' and len(points.split()) == 2:
        aliases.append(''.join(chr(int(cp, 16) - 0x1F1E6 + ord('A')) for cp in points.split()))
    if name == 'flag: United States': aliases.extend(['usa', 'america', 'american'])
    if name == 'flag: United Kingdom': aliases.extend(['uk', 'britain', 'british'])
    entries.append(dict(glyph=glyph, name=name, group=group, subgroup=subgroup, aliases=' '.join(aliases)))
output = pathlib.Path(__file__).resolve().parents[1] / 'Horologium/Resources/Emoji.json'
output.write_text(json.dumps(entries, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'Wrote {len(entries):,} emoji')
