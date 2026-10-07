#!/usr/bin/env python3
"""Collect simulator exports, then run the independent FFmpeg media oracle."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True, help='Booted iOS simulator UDID')
    parser.add_argument('--bundle-id', required=True, help='Runner.app CFBundleIdentifier')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    container = Path(subprocess.check_output(
        ['xcrun', 'simctl', 'get_app_container', args.device, args.bundle_id, 'data'],
        text=True,
    ).strip())
    matches = [path for path in container.rglob('fluvie_release_acceptance')
               if (path / 'device-report.json').is_file()]
    if len(matches) != 1:
        raise RuntimeError(f'Expected one retained media acceptance directory, found {matches}')
    args.output.mkdir(parents=True, exist_ok=True)
    for name in ['source.mp4', 'ramp_160.mp4', 'ramp_128.mp4', 'device-report.json']:
        shutil.copy2(matches[0] / name, args.output / name)
    (args.output / 'simulator.json').write_text(json.dumps({
        'device': args.device,
        'bundleId': args.bundle_id,
        'runtime': subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes'], text=True),
    }, indent=2) + '\n')
    subprocess.run([
        sys.executable, str(Path(__file__).with_name('verify_android_media.py')),
        '--platform', 'ios', '--no-pull', '--output', str(args.output),
    ], check=True)


if __name__ == '__main__':
    main()
