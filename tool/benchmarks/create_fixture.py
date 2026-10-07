#!/usr/bin/env python3
"""Create a fresh, synthetic authoring benchmark project without provider calls."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--ffmpeg', default='ffmpeg')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    project = args.directory.resolve()
    if project.exists():
        parser.error('Choose a new directory; existing projects are never overwritten.')

    def run(*command, cwd=root):
        subprocess.run(command, cwd=cwd, check=True)

    run('flutter', 'create', '--empty', '--platforms=linux', '--project-name=fluvie_authoring_fixture', str(project))
    run('dart', '--packages=' + str(root / '.dart_tool/package_config.json'),
        str(root / 'packages/fluvie_cli/bin/fluvie.dart'), 'init', '--dir', str(project),
        '--fluvie-path', str(root), '--with-ai', '--name', 'benchmark_seed')
    run('flutter', 'pub', 'get', cwd=project)
    assets = project / 'assets'
    assets.mkdir(exist_ok=True)
    base = [args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-nostdin', '-y']
    run(*base, '-f', 'lavfi', '-i', 'color=c=navy:s=160x160:r=30:d=2',
        '-vf', 'drawbox=x=55:y=55:w=50:h=50:color=red:t=fill', '-frames:v', '1', str(assets / 'ball.png'))
    run(*base, '-f', 'lavfi', '-i', 'color=c=navy:s=160x160:r=30:d=2',
        '-vf', 'drawbox=x=55:y=55:w=50:h=50:color=red:t=fill', '-pix_fmt', 'yuv420p', str(assets / 'play.mp4'))
    run(*base, '-f', 'lavfi', '-i', 'sine=frequency=440:duration=10', str(assets / 'music.wav'))
    (assets / 'story.txt').write_text('Milo is a fictional cat. He plays with a red ball, then rests.\n'
        'These assets are synthetic shapes and tones, not footage of a real cat.\n')
    (assets / 'captions.srt').write_text('1\n00:00:00,000 --> 00:00:02,000\nMilo plays\n\n'
        '2\n00:00:02,000 --> 00:00:06,000\nMilo rests\n')
    shutil.copyfile(root / 'examples/gallery/lib/authoring/benchmark_fixture.dart', project / 'lib/custom_video.dart')
    shutil.copyfile(root / 'tool/benchmarks/authoring_suite.json', project / 'authoring_suite.json')
    print(json.dumps({'project': str(project), 'suite': str(project / 'authoring_suite.json')}))


if __name__ == '__main__':
    main()
