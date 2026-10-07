import 'dart:async';
import 'dart:typed_data';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:http/http.dart' as http;

/// The only hosts Fluvie will fetch a managed FFmpeg build from (the origins of
/// the pinned URLs in the release table). A strict allowlist, per the security
/// security rule: even though the URLs are compiled-in constants, the
/// downloader refuses anything off this list as defense in depth.
const Set<String> ffmpegDownloadHostAllowlist = {
  'github.com',
  'evermeet.cx',
  'www.osxexperts.net',
};

/// Fetches the bytes of a pinned FFmpeg archive. Injectable so the provisioner
/// can be unit-tested without a network.
// ignore: one_member_abstracts — the seam is the type; a function can't be mocked the same way.
abstract interface class FfmpegDownloader {
  /// Downloads every byte at [url]. Throws a [CliFailure] on a disallowed URL,
  /// a transport error, or a non-200 response.
  Future<List<int>> download(String url);
}

/// An optional downloader that bounds the bytes consumed from the response.
abstract interface class BoundedFfmpegDownloader implements FfmpegDownloader {
  /// Downloads at most [maxBytes], rejecting larger responses before buffering them.
  Future<List<int>> downloadBounded(String url, {required int maxBytes});
}

/// The real [FfmpegDownloader]: a `package:http` GET that follows redirects
/// (GitHub release URLs redirect to their CDN) and validates the origin.
final class HttpFfmpegDownloader implements BoundedFfmpegDownloader {
  /// Creates a downloader over an injected client, or an owned client per download.
  HttpFfmpegDownloader([this._client]);

  final http.Client? _client;

  /// Direct downloads allow up to 256 MiB, covering every pinned platform archive.
  static const int maxArchiveBytes = 256 * 1024 * 1024;

  static const _timeout = Duration(minutes: 10);

  @override
  Future<List<int>> download(String url) => downloadBounded(url, maxBytes: maxArchiveBytes);

  @override
  Future<List<int>> downloadBounded(String url, {required int maxBytes}) async {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || !ffmpegDownloadHostAllowlist.contains(uri.host)) {
      throw CliFailure(
        'Refusing to download FFmpeg from a URL outside the host allowlist: $url',
      );
    }
    final client = _client ?? http.Client();
    final clock = Stopwatch()..start();
    StreamIterator<List<int>>? body;
    try {
      final response = await client.send(http.Request('GET', uri)).timeout(_timeout);
      final declared = response.contentLength;
      final rejection = response.statusCode != 200
          ? CliFailure('Downloading FFmpeg from $url failed with HTTP ${response.statusCode}.')
          : declared != null && declared > maxBytes
          ? _oversized(url, maxBytes)
          : null;
      if (rejection != null) {
        await response.stream.listen(null).cancel();
        throw rejection;
      }
      final reader = StreamIterator<List<int>>(response.stream);
      body = reader;
      final bytes = BytesBuilder(copy: false);
      Future<List<int>> read() async {
        while (await reader.moveNext()) {
          final chunk = reader.current;
          if (bytes.length + chunk.length > maxBytes) throw _oversized(url, maxBytes);
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      }

      return await read().timeout(_timeout - clock.elapsed);
    } on http.ClientException catch (error) {
      throw CliFailure('Could not download FFmpeg from $url (${error.message}).');
    } on TimeoutException {
      throw CliFailure(
        'Downloading FFmpeg from $url timed out. Retry `fluvie ffmpeg install` or use --toolchain system.',
      );
    } finally {
      if (_client == null) client.close();
      await body?.cancel();
    }
  }

  static CliFailure _oversized(String url, int maxBytes) => CliFailure(
    'Downloading FFmpeg from $url exceeds the archive limit of $maxBytes bytes.',
    code: 'toolchain_archive_too_large',
    details: {'url': url, 'maxBytes': maxBytes},
  );
}
