/// An FFmpeg `major.minor` version parsed from a `-version` banner, with the
/// `>= 6.0` floor this library requires.
///
/// The floor is enforced by `ProcessFfmpegProvider` (and, independently, by
/// the CLI's own probe) before any encode starts; an embedded wasm runtime
/// has no honest banner to parse, so its provider reports no version at all
/// rather than a fabricated one.
final class FfmpegVersion {
  /// Creates a version from its parsed [major] and [minor] components.
  const FfmpegVersion(this.major, this.minor);

  /// The lowest FFmpeg major version Fluvie supports.
  static const int floorMajor = 6;

  /// Matches the `major.minor` pair on the banner's **first line only**
  /// (`^` is unanchored to later lines), tolerating git tags like `n7.0` and
  /// distro suffixes like `6.1.1-3ubuntu5`. Anchoring keeps a git-snapshot
  /// banner (`ffmpeg version N-...` + `built with gcc 12.2.0`) from silently
  /// parsing the compiler's version instead of FFmpeg's.
  static final RegExp _versionPattern = RegExp(r'^ffmpeg version [^0-9]{0,2}(\d+)\.(\d+)');

  /// The major version component.
  final int major;

  /// The minor version component.
  final int minor;

  /// Parses [banner] (`ffmpeg -version` output, starting with
  /// `ffmpeg version `), or returns `null` when its first line carries no
  /// `major.minor` pair — unparsable banners are rejected by callers with a
  /// clear message, never guessed at.
  static FfmpegVersion? parse(String banner) {
    final match = _versionPattern.firstMatch(banner);
    if (match == null) return null;
    return FfmpegVersion(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Whether this version satisfies the `>= 6.0` floor.
  bool get meetsFloor => major >= floorMajor;

  @override
  String toString() => '$major.$minor';
}
