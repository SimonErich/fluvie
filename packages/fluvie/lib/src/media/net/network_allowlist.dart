import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:meta/meta.dart';

/// The network safety gate consulted before any media fetch.
///
/// A `MediaRepository` calls [check] on every network URL before handing it to
/// the HTTP client. Only allowlisted [hosts] over allowlisted [schemes] pass;
/// everything else is a typed [FluvieRenderException] that names the offending
/// host or scheme. This keeps a render from reaching an arbitrary endpoint and
/// keeps the determinism story honest: the set of reachable origins is
/// declared up front, never discovered at fetch time.
@immutable
final class NetworkAllowlist {
  /// Creates an allowlist permitting exactly [hosts] over [schemes].
  ///
  /// [schemes] defaults to `{'https'}` — `http` must be opted in explicitly.
  // coverage:ignore-line: const-ctor artifact, allow/deny behavior pinned by allowlist tests
  const NetworkAllowlist({required this.hosts, this.schemes = const {'https'}})
    : _allowAnyHost = false;

  const NetworkAllowlist._anyHost(this.schemes) : hosts = const {}, _allowAnyHost = true;

  /// An allowlist that permits any host over [schemes] (defaults to https).
  ///
  /// Use sparingly: it disables host filtering. Scheme filtering still applies.
  factory NetworkAllowlist.allowAny({Set<String> schemes = const {'https'}}) =>
      NetworkAllowlist._anyHost(schemes);

  /// The hosts permitted to be fetched (exact match, case-sensitive).
  final Set<String> hosts;

  /// The URL schemes permitted (lower-case, for example `https`).
  final Set<String> schemes;

  final bool _allowAnyHost;

  /// Throws a [FluvieRenderException] when [url] is not permitted; returns
  /// normally otherwise.
  void check(Uri url) {
    if (!schemes.contains(url.scheme)) {
      throw FluvieRenderException(
        'Disallowed URL scheme "${url.scheme}" for "$url". The network '
        'allowlist permits only: ${schemes.join(', ')}.',
      );
    }
    if (url.host.isEmpty) {
      throw FluvieRenderException('Network URL "$url" has no host to check against the allowlist.');
    }
    if (!_allowAnyHost && !hosts.contains(url.host)) {
      throw FluvieRenderException(
        'Disallowed host "${url.host}" for "$url". The network allowlist '
        'permits only: ${hosts.join(', ')}.',
      );
    }
  }
}
