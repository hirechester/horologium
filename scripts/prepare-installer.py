#!/usr/bin/env python3
"""Prepare native Installer resources and customize a synthesized distribution."""
import json
from pathlib import Path
import plistlib
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
work = root / 'build/installer'
resources = work / 'Resources'
resources.mkdir(parents=True, exist_ok=True)
version = json.loads((root / 'Version.json').read_text())


def rtf(text):
    return text.replace('\\', r'\\').replace('{', r'\{').replace('}', r'\}')


def document(body):
    return r'{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\viewkind4\uc1\f0\fs24 ' + body + '}'


if sys.argv[1] == 'prepare':
    welcome = (
        r'\qc '
        r'\fs36\b Horologium\b0\fs24\par\par\ql '
        'Your calendar and world clocks, right in the menu bar.' + r'\par\par '
        'Browse the calendar, save locations with custom labels and native emoji, '
        'and slide through time to find a moment that works across time zones.' + r'\par\par '
        'Horologium works entirely offline. No accounts, conferencing integrations, '
        'or event notifications.' + r'\par\par '
        'This installer adds Horologium to your Applications folder.' + r'\par\par\fs20 '
        + rtf(f"Version {version['version']} (build {version['build']})")
    )
    conclusion = (
        r'\fs32\b Ready for your menu bar\b0\fs24\par\par '
        'Open Horologium from your Applications folder to get started.' + r'\par\par '
        'Click its menu bar item to open the calendar and world clocks. '
        'Right-click the menu bar item to open Settings or quit.' + r'\par\par '
        'Moving from another Mac? Import your exported JSON settings in Settings > General.'
    )
    (resources / 'Welcome.rtf').write_text(document(welcome))
    (resources / 'Conclusion.rtf').write_text(document(conclusion))
    with (work / 'components.plist').open('wb') as file:
        plistlib.dump([dict(RootRelativeBundlePath='Applications/Horologium.app',
                           BundleIsRelocatable=False, BundleIsVersionChecked=True,
                           BundleHasStrictIdentifier=True, BundleOverwriteAction='upgrade')], file)
    with (work / 'requirements.plist').open('wb') as file:
        plistlib.dump(dict(os=['26.0'], arch=['arm64']), file)
elif sys.argv[1] == 'distribution':
    path = work / 'Distribution.xml'
    tree = ET.parse(path)
    distribution = tree.getroot()
    title = distribution.find('title')
    if title is None:
        title = ET.SubElement(distribution, 'title')
    title.text = 'Horologium'
    for name in ['background', 'background-darkAqua']:
        ET.SubElement(distribution, name, file='Logo.png', alignment='bottomleft',
                      scaling='none', **{'mime-type': 'image/png'})
    for name, filename in [('welcome', 'Welcome.rtf'), ('conclusion', 'Conclusion.rtf')]:
        ET.SubElement(distribution, name, file=filename, **{'mime-type': 'text/rtf'})
    ET.indent(tree, space='  ')
    tree.write(path, encoding='utf-8', xml_declaration=True)
else:
    raise SystemExit('Usage: prepare-installer.py prepare|distribution')
