import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Color,
        CustomPaint,
        EdgeInsets,
        Key,
        Padding,
        Positioned,
        Stack,
        StatelessWidget,
        Text,
        TextOverflow,
        TextStyle,
        Widget;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/snapshot/render/device_frame_painter.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';

/// Wraps any child in pure presentational device chrome: a phone bezel, a
/// browser window with an address bar, or a tablet bezel.
///
/// `DeviceFrame` is **only** chrome. It draws no raster, calls no
/// `SnapshotService`, and is not a `MediaCarrier` — it composes over *any*
/// child: a `WebView`, `Mermaid`, `Image`, `Snapshot`, or a plain Flutter
/// widget. Mirroring `TerminalChrome`, the chrome colors come from
/// `context.fluvie.code` (the bezel from `background`, the notch / address bar
/// from `chromeColor`, the url text from `lineNumberColor`), so a
/// `FluvieTokensScope` rebrands every frame at once.
///
/// ```dart
/// DeviceFrame.browser(
///   url: 'https://example.com',
///   child: WebView.url('https://example.com', viewport: viewport),
/// );
/// DeviceFrame.phone(child: const Mermaid('graph TD; A-->B;'));
/// ```
///
/// The chrome is painted behind the child by a capture-safe
/// [DeviceFramePainter] (no `saveLayer`); the child renders inside the content
/// inset. An optional [shared] anchor wraps the framed result in a
/// `SharedElement` for a hero morph across a scene boundary.
/// Transforms and effects come through `.animate()` only, like every element.
final class DeviceFrame extends StatelessWidget implements CollectibleChildren {
  /// The base constructor every named factory delegates to; carries the resolved
  /// [style] and chrome inputs.
  const DeviceFrame._({
    required this.style,
    required this.child,
    this.url,
    this.notch = false,
    this.shared,
    super.key,
  });

  /// A phone bezel around [child], with an optional top [notch] (default on).
  const DeviceFrame.phone({
    required Widget child,
    bool notch = true,
    Anchor? shared,
    Key? key,
  }) : this._(style: DeviceFrameStyle.phone, child: child, notch: notch, shared: shared, key: key);

  /// A browser window around [child], with a top address bar carrying three
  /// traffic-light dots and the optional [url] text.
  const DeviceFrame.browser({
    required Widget child,
    String? url,
    Anchor? shared,
    Key? key,
  }) : this._(style: DeviceFrameStyle.browser, child: child, url: url, shared: shared, key: key);

  /// A thinner tablet bezel around [child] (no notch, no address bar).
  const DeviceFrame.tablet({
    required Widget child,
    Anchor? shared,
    Key? key,
  }) : this._(style: DeviceFrameStyle.tablet, child: child, shared: shared, key: key);

  /// Which device chrome this frame paints.
  final DeviceFrameStyle style;

  /// The widget rendered inside the frame's content area.
  final Widget child;

  /// The url shown in the browser address bar, or `null` for an empty bar. Only
  /// a [DeviceFrame.browser] carries a url.
  final String? url;

  /// Whether a phone notch is drawn. Only a [DeviceFrame.phone] sets this; the
  /// browser and tablet styles never draw a notch.
  final bool notch;

  /// An optional hero anchor: when non-null the framed child morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// Whether this style paints a browser address bar.
  bool get _hasAddressBar => style == DeviceFrameStyle.browser;

  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) {
    final code = context.fluvie.code;
    final painter = DeviceFramePainter(
      style: style,
      bezelColor: code.background,
      chromeColor: code.chromeColor,
      urlColor: code.lineNumberColor,
      notch: notch && style == DeviceFrameStyle.phone,
      showAddressBar: _hasAddressBar,
      url: _hasAddressBar ? url : null,
    );
    final framed = CustomPaint(
      painter: painter,
      child: Padding(padding: _contentInset(painter), child: child),
    );
    final withChrome = _hasAddressBar && url != null
        ? Stack(children: [framed, _urlLabel(code.lineNumberColor, painter.addressBarHeight)])
        : framed;
    return wrapShared(shared, withChrome);
  }

  /// Insets the [child] so it renders inside the bezel and below any address bar.
  EdgeInsets _contentInset(DeviceFramePainter painter) {
    final bezel = painter.bezelThickness;
    return EdgeInsets.fromLTRB(bezel, bezel + painter.addressBarHeight, bezel, bezel);
  }

  /// The address-bar url, rendered as a real [Text] so it carries the font and
  /// is findable, positioned over the bar past the traffic-light dots.
  Widget _urlLabel(Color color, double barHeight) => Positioned(
    left: 64,
    right: 16,
    top: 0,
    height: barHeight,
    child: Text(
      url!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 12),
    ),
  );
}
