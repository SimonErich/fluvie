/// The directory base relative `file` media values resolve against.
///
/// A `.fluvie` document saved next to its media can reference it
/// relative to its own folder — `{"kind": "file", "value": "media/intro.mp4"}`
/// — so the folder travels as one portable unit and the digest stays
/// machine-stable. The value stays relative in the JSON; only its
/// *resolution* is scoped: the loader that opened the document sets the
/// document's directory here, and the element codec joins relative file
/// values onto it at build time. Absolute values pass through verbatim, and
/// without a scope every value passes through unchanged, so absolute-path
/// documents behave exactly as before.
///
/// The scope has the two `BundleMedia` shapes: [current] is the loader's
/// session slot (element builds happen across frames, so the loader owns it
/// for as long as its document is open), and [resolve] runs one build under
/// a scoped base, restoring the previous one on exit — for renders and
/// tests.
final class MediaFileBase {
  const MediaFileBase._();

  /// The document directory relative file values currently resolve against,
  /// or null when no document scope is set. The loader that opened a
  /// document owns this slot: set it when the document opens, clear it when
  /// the document closes.
  static String? current;

  /// Runs [build] with [base] as the resolution scope and returns its
  /// result; the previous scope is restored on exit. Passing null builds
  /// without a base — relative values then pass through unchanged.
  static T resolve<T>(String? base, T Function() build) {
    final previous = current;
    current = base;
    try {
      return build();
    } finally {
      current = previous;
    }
  }

  /// [value] joined onto [current] when it is relative and a scope is set;
  /// otherwise [value] verbatim.
  static String resolvePath(String value) {
    final base = current;
    if (base == null || isAbsolute(value)) return value;
    return join(base, value);
  }

  /// Whether [value] is already an absolute media path: a POSIX root, a
  /// Windows drive, or a UNC share. Absolute values pass through resolution
  /// verbatim; relative ones join onto the document [current].
  static bool isAbsolute(String value) =>
      value.startsWith('/') ||
      value.startsWith(r'\\') ||
      RegExp(r'^[A-Za-z]:[/\\]').hasMatch(value);

  /// [value] joined onto directory [base] with a single separator — the join
  /// a relative media value resolves through.
  static String join(String base, String value) =>
      base.endsWith('/') ? '$base$value' : '$base/$value';
}
