// WI-18 (D-Captions, D-ResolverGrow, §17): the caption pre-pass grown onto
// MediaRepository. preResolveCaptions reads + parses the SRT/VTT file once
// before frame 0; cuesFor serves the parsed cues synchronously and throws on an
// unresolved source naming it. Inline captions need no IO.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._data);
  final Map<String, Uint8List> _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = _data[key];
    if (bytes == null) throw FluvieRenderException('asset not found: $key');
    return ByteData.view(bytes.buffer);
  }
}

class _CountingHttpClient implements MediaHttpClient {
  int calls = 0;
  @override
  Future<Uint8List> get(Uri url) async {
    calls++;
    throw FluvieRenderException('no canned bytes for "$url"');
  }
}

const _srt = '1\n00:00:00,000 --> 00:00:02,000\nHello world\n';
const _vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nHi there\n';

MediaRepository _repo(Map<String, Uint8List> assets) => MediaRepository(
  loader: MediaBytesLoader(
    bundle: _MapBundle(assets),
    httpClient: _CountingHttpClient(),
    allowlist: NetworkAllowlist.allowAny(),
  ),
);

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('MediaRepository.preResolveCaptions + cuesFor', () {
    test('reads and parses an SRT file into cues', () async {
      final repo = _repo({'en.srt': _bytes(_srt)});
      const source = CaptionSource.srt('en.srt');

      await repo.preResolveCaptions(source);
      final cues = repo.cuesFor(source);

      expect(cues, hasLength(1));
      expect(cues.single.text, 'Hello world');
      expect(cues.single.end, 2.0.seconds);
    });

    test('reads and parses a VTT file into cues', () async {
      final repo = _repo({'en.vtt': _bytes(_vtt)});
      const source = CaptionSource.vtt('en.vtt');

      await repo.preResolveCaptions(source);
      expect(repo.cuesFor(source).single.text, 'Hi there');
    });

    test('an inline source needs no IO and serves its words as cues', () async {
      final repo = _repo(const {});
      final source = CaptionSource.inline([
        CaptionWord('Hello', at: 0.0.seconds),
        CaptionWord('world', at: 0.4.seconds),
      ]);

      await repo.preResolveCaptions(source);
      final cues = repo.cuesFor(source);
      expect(cues, hasLength(2));
      expect(cues.first.text, 'Hello');
    });

    test('is idempotent: parsing the same source twice reads once', () async {
      final repo = _repo({'en.srt': _bytes(_srt)});
      const source = CaptionSource.srt('en.srt');
      await repo.preResolveCaptions(source);
      final first = repo.cuesFor(source);
      await repo.preResolveCaptions(source);
      expect(repo.cuesFor(source), first);
    });

    test('cuesFor before preResolveCaptions throws StateError', () {
      final repo = _repo(const {});
      expect(() => repo.cuesFor(const CaptionSource.srt('en.srt')), throwsStateError);
    });

    test('cuesFor for an unresolved source throws naming it', () async {
      final repo = _repo({'en.srt': _bytes(_srt)});
      await repo.preResolveCaptions(const CaptionSource.srt('en.srt'));
      expect(
        () => repo.cuesFor(const CaptionSource.srt('de.srt')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('de.srt')),
        ),
      );
    });
  });
}
