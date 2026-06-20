import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:http/http.dart' as http;

/// The only hosts Fluvie will fetch a managed FFmpeg build from (the origins of
/// the pinned URLs in the release table). A strict allowlist, per the security
/// rule in CLAUDE.md: even though the URLs are compiled-in constants, the
/// downloader refuses anything off this list as defense in depth.
const Set<String> ffmpegDownloadHostAllowlist = {
  'github.com',
  'evermeet.cx',
  'www.osxexperts.net',
};

/// Fetches the bytes of a pinned FFmpeg archive. Injectable so the provisioner
/// can be unit-tested without a network.
// The seam is the type; a function could not be mocked the same way.
// ignore: one_member_abstracts
abstract interface class FfmpegDownloader {
  /// Downloads every byte at [url]. Throws a [CliFailure] on a disallowed URL,
  /// a transport error, or a non-200 response.
  Future<List<int>> download(String url);
}

/// The real [FfmpegDownloader]: a `package:http` GET that follows redirects
/// (GitHub release URLs redirect to their CDN) and validates the origin.
final class HttpFfmpegDownloader implements FfmpegDownloader {
  /// Creates a downloader over [client] (default: a fresh `http.Client`).
  HttpFfmpegDownloader([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<int>> download(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || !ffmpegDownloadHostAllowlist.contains(uri.host)) {
      throw CliFailure(
        'Refusing to download FFmpeg from a URL outside the host allowlist: $url',
      );
    }
    final http.Response response;
    try {
      response = await _client.get(uri);
    } on http.ClientException catch (error) {
      throw CliFailure('Could not download FFmpeg from $url (${error.message}).');
    }
    if (response.statusCode != 200) {
      throw CliFailure(
        'Downloading FFmpeg from $url failed with HTTP ${response.statusCode}.',
      );
    }
    return response.bodyBytes;
  }
}
