#!/usr/bin/env python3
"""Index public soft-deprecated declarations from the active SwiftUI SDK interfaces."""
import argparse
import json
from pathlib import Path
import re
import subprocess


def extract(path):
    lines = path.read_text().splitlines()
    records = []
    visited = set()
    for index, line in enumerate(lines):
        if not re.search(r"deprecated:\s*100000(?:\.0)?\b", line):
            continue
        start = index
        while start > 0 and lines[start - 1].lstrip().startswith('@'):
            start -= 1
        end = index
        while end < len(lines) and not re.search(r'\b(public|extension)\b', lines[end]):
            end += 1
        if end == len(lines) or end - index > 16 or end in visited:
            continue
        # Retain neighboring platform availability attributes and the declaration's first line.
        # The SDK is authoritative for enclosing type/extension availability and full signature.
        if 'public ' not in lines[end] and not lines[end].lstrip().startswith('extension '):
            continue
        visited.add(end)
        records.append({'interface': str(path), 'line': end + 1,
                        'declaration': lines[end].strip(),
                        'attributes': '\n'.join(lines[start:end])})
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', default='iphonesimulator')
    parser.add_argument('--symbol', default='', help='Filter declarations by a case-sensitive substring')
    args = parser.parse_args()
    sdk = Path(subprocess.check_output(['xcrun', '--sdk', args.sdk, '--show-sdk-path'], text=True).strip())
    records = []
    for framework in ('SwiftUI', 'SwiftUICore'):
        module = sdk / 'System/Library/Frameworks' / (framework + '.framework') / 'Modules' / (framework + '.swiftmodule')
        candidates = sorted(p for p in module.glob('*.swiftinterface') if '.private.' not in p.name)
        if not candidates:
            raise SystemExit('No public interface found for ' + framework)
        selected = next((p for p in candidates if p.name.startswith('arm64-')), candidates[0])
        records.extend(extract(selected))
    print(json.dumps({'sdk': str(sdk), 'records': [r for r in records if args.symbol in r['declaration']]}, indent=2))


if __name__ == '__main__':
    main()
