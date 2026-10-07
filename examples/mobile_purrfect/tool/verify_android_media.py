#!/usr/bin/env python3
"""Pull and independently decode native_media_acceptance_test.dart exports.

Requires adb, ffprobe and ffmpeg on PATH. The device test must pass first.
All expected values are derived from the authored fixture, not native reports.
"""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess


def run(args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def verify(path, frames, size, ramp, *, rate_changes_pitch=True):
    probe = json.loads(run(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                            '-of', 'json', str(path)]))
    video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
    assert video['codec_name'] == 'h264', video
    assert (video['width'], video['height']) == (size, size), video
    assert int(video['nb_frames']) == frames, video
    assert video['r_frame_rate'] == '24/1', video
    assert audio['codec_name'] == 'aac', audio
    assert audio['channels'] in ([2] if rate_changes_pitch else [1, 2]), audio
    for stream in [video, audio]:
        assert abs(float(stream['duration']) - frames / 24) <= 0.001, stream
        assert abs(float(stream['start_time'])) <= 0.001, stream
    first_audio_packet = json.loads(run([
        'ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_packets',
        '-read_intervals', '%+#1', '-of', 'json', str(path),
    ]))['packets'][0]
    timestamps = json.loads(run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                                 '-show_frames', '-show_entries', 'frame=best_effort_timestamp_time',
                                 '-of', 'json', str(path)]))['frames']
    assert len(timestamps) == frames, len(timestamps)
    maximum_timestamp_error = max(abs(float(frame['best_effort_timestamp_time']) - i / 24)
                                  for i, frame in enumerate(timestamps))
    assert maximum_timestamp_error < 0.001, maximum_timestamp_error
    pixels = run(['ffmpeg', '-v', 'error', '-threads', '1', '-i', str(path),
                  '-map', '0:v:0', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
    frame_bytes = size * size * 3
    assert len(pixels) == frames * frame_bytes, (len(pixels), frames * frame_bytes)
    maximum_error = 0
    samples = []
    for frame in range(frames):
        t = frame / 24
        source_frame = math.floor((0.25 + 0.5 * t + t * t / 6) * 24 + 1e-8) if ramp else frame
        expected = [238, 12, 12] if source_frame < 48 else [12, 12, 238]
        # Check separated patches in every decoded frame, including frame zero
        # of both consecutive ramp exports and the exact colour-change boundary.
        for x, y in [(size // 4, size // 4), (size // 2, size // 2), (3 * size // 4, 3 * size // 4)]:
            offset = frame * frame_bytes + (y * size + x) * 3
            actual = list(pixels[offset:offset + 3])
            error = max(abs(a - b) for a, b in zip(actual, expected))
            maximum_error = max(maximum_error, error)
            assert error <= 18, {'file': str(path), 'frame': frame, 'source_frame': source_frame,
                                 'pixel': actual, 'expected': expected, 'error': error}
            if x == size // 2 and frame in [0, 24, 48, 51, 52, 60, frames - 1]:
                samples.append({'frame': frame, 'source_frame': source_frame, 'rgb': actual})
    pcm = array.array('f', run(['ffmpeg', '-v', 'error', '-threads', '1', '-i', str(path),
                                '-map', '0:a:0', '-af', 'pan=mono|c0=c0', '-ar', '44100', '-f', 'f32le', '-']))
    measurements = []
    for middle in [0.6, 1.5, 2.4]:
        start, end = int((middle - 0.1) * 44100), int((middle + 0.1) * 44100)
        segment = pcm[start:end]
        rms = math.sqrt(sum(v * v for v in segment) / len(segment))
        crossings = sum(a <= 0 < b for a, b in zip(segment, segment[1:]))
        frequency = crossings * 44100 / len(segment)
        expected_gain = 0.2 + 0.2 * middle if ramp else 1
        expected_rms = 0.4 / math.sqrt(2) * expected_gain
        # Android's documented nearest-neighbour resampling changes pitch.
        source_time = 0.25 + 0.5 * middle + middle * middle / 6 if ramp else middle
        source_frequency = 400 if source_time < 2 else 800
        expected_frequency = source_frequency * (0.5 + middle / 3) if ramp and rate_changes_pitch else source_frequency
        assert abs(rms - expected_rms) <= expected_rms * 0.13, (path, middle, rms, expected_rms)
        assert abs(frequency - expected_frequency) <= 12, (path, middle, frequency, expected_frequency)
        measurements.append({'seconds': middle, 'rms': rms, 'expected_rms': expected_rms,
                             'frequency_hz': frequency, 'expected_frequency_hz': expected_frequency})
    event_time = (math.sqrt(51) - 3) / 2 if ramp else 2.0
    def frequency_between(start, end):
        segment = pcm[int(start * 44100):int(end * 44100)]
        crossings = sum(a <= 0 < b for a, b in zip(segment, segment[1:]))
        return crossings * 44100 / len(segment)
    threshold = 600 * (0.5 + event_time / 3) if ramp and rate_changes_pitch else 600
    before_event = frequency_between(event_time - 0.055, event_time - 0.025)
    after_event = frequency_between(event_time + 0.025, event_time + 0.055)
    assert before_event < threshold < after_event, (path, event_time, before_event, threshold, after_event)
    if ramp:
        def rms_at(start, end):
            segment = pcm[int(start * 44100):int(end * 44100)]
            return math.sqrt(sum(v * v for v in segment) / len(segment))
        assert rms_at(0.025, 0.075) < rms_at(0.3, 0.4) * 0.4, 'fade-in was not applied'
        assert rms_at(2.925, 2.975) < rms_at(2.5, 2.6) * 0.4, 'fade-out was not applied'
    return {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'video_frames_verified': frames, 'maximum_rgb_error': maximum_error,
            'maximum_timestamp_error_seconds': maximum_timestamp_error,
            'pixel_samples': samples, 'audio_measurements': measurements,
            'source_audio_event': {'expected_seconds': event_time, 'before_hz': before_event, 'after_hz': after_event},
            'first_audio_packet': first_audio_packet,
            'probe': probe}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', default='emulator-5570')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--device-directory', default='code_cache/fluvie_release_acceptance')
    parser.add_argument('--no-pull', action='store_true')
    parser.add_argument('--platform', choices=['android', 'ios'], default='android')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    names = ['device-report.json', 'source.mp4', 'ramp_160.mp4', 'ramp_128.mp4']
    if not args.no_pull:
        for name in names:
            data = run(['adb', '-s', args.serial, 'exec-out', 'run-as',
                        'dev.fluvie.mobile_purrfect', 'cat', f'{args.device_directory}/{name}'])
            if name.endswith('.json'):
                json.loads(data)  # Reject adb's textual error before overwriting artifacts.
            elif data[4:8] != b'ftyp':
                raise RuntimeError(f'No completed MP4 for {name}; run the device test first: {data[:200]!r}')
            (args.output / name).write_bytes(data)
        (args.output / 'android-properties.txt').write_bytes(run(['adb', '-s', args.serial, 'shell', 'getprop']))
    report = {'passed': False, 'platform': args.platform, 'outputs': []}
    try:
        for name, count, size, ramp in [('source.mp4', 96, 160, False),
                                       ('ramp_160.mp4', 72, 160, True),
                                       ('ramp_128.mp4', 72, 128, True)]:
            report['outputs'].append(verify(args.output / name, count, size, ramp, rate_changes_pitch=args.platform == 'android'))
        report['passed'] = True
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        (args.output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"Verified 240 video frames and source/ramped/faded audio: {args.output / 'verification.json'}")


if __name__ == '__main__':
    main()
