#!/usr/bin/env python3
"""Bump version and build once per delivered update, then regenerate Xcode settings.
Usage: python3 scripts/bump-version.py [patch|minor|major] (default: patch).
Routine rebuilds and tests retain the same version/build pair.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('part', choices=['patch', 'minor', 'major'], nargs='?', default='patch')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
path = root / 'Version.json'
current = json.loads(path.read_text())
parts = [int(x) for x in current['version'].split('.')]
if len(parts) != 3:
    parser.error('Version.json must contain a major.minor.patch version')
index = {'major': 0, 'minor': 1, 'patch': 2}[args.part]
parts[index] += 1
for i in range(index + 1, 3):
    parts[i] = 0
current['version'] = '.'.join(map(str, parts))
current['build'] += 1
path.write_text(json.dumps(current, indent=2) + '\n')
subprocess.run([sys.executable, str(root / 'scripts/generate-project.py')], check=True)
print(f"Version {current['version']} (build {current['build']})")
