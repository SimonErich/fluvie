import 'package:flutter/widgets.dart';

import '../domain/sync_anchor_info.dart';

/// A registry that collects and provides access to [SyncAnchor] timing information.
///
/// This InheritedWidget is placed near the root of a composition and allows
/// descendant widgets to register their sync anchors and query other anchors.
///
/// ## Usage
///
/// The registry is typically created automatically by [VideoComposition] or
/// [RenderableComposition]. You can access it via [SyncAnchorRegistry.of]:
///
/// ```dart
/// final registry = SyncAnchorRegistry.of(context);
/// final anchorInfo = registry?.getAnchor('intro_text');
/// if (anchorInfo != null) {
///   final syncedStart = anchorInfo.startFrameWithOffset(10);
/// }
/// ```
class SyncAnchorRegistry extends InheritedWidget {
  /// The registry data that stores all anchor information.
  final SyncAnchorRegistryData data;

  /// Creates a sync anchor registry.
  const SyncAnchorRegistry({
    super.key,
    required this.data,
    required super.child,
  });

  /// Retrieves the nearest [SyncAnchorRegistry] ancestor.
  ///
  /// Returns null if no registry is found in the widget tree.
  static SyncAnchorRegistry? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SyncAnchorRegistry>();
  }

  /// Retrieves the nearest registry data without creating a dependency.
  ///
  /// Use this for registration to avoid unnecessary rebuilds.
  static SyncAnchorRegistryData? maybeOf(BuildContext context) {
    final widget = context.getInheritedWidgetOfExactType<SyncAnchorRegistry>();
    return widget?.data;
  }

  @override
  bool updateShouldNotify(SyncAnchorRegistry oldWidget) {
    return data != oldWidget.data;
  }
}

/// The data store for sync anchor information.
///
/// This class manages the registration and lookup of sync anchors.
/// It's designed to be created once and shared via [SyncAnchorRegistry].
class SyncAnchorRegistryData extends ChangeNotifier {
  final Map<String, SyncAnchorInfo> _anchors = {};

  /// All registered anchors.
  Map<String, SyncAnchorInfo> get anchors => Map.unmodifiable(_anchors);

  /// Registers a sync anchor.
  ///
  /// If an anchor with the same ID already exists, it will be replaced
  /// and listeners will be notified.
  void registerAnchor(SyncAnchorInfo anchor) {
    final existing = _anchors[anchor.anchorId];
    if (existing != anchor) {
      _anchors[anchor.anchorId] = anchor;
      notifyListeners();
    }
  }

  /// Unregisters a sync anchor by ID.
  void unregisterAnchor(String anchorId) {
    if (_anchors.containsKey(anchorId)) {
      _anchors.remove(anchorId);
      notifyListeners();
    }
  }

  /// Gets a sync anchor by ID.
  ///
  /// Returns null if no anchor with that ID is registered.
  SyncAnchorInfo? getAnchor(String anchorId) {
    return _anchors[anchorId];
  }

  /// Checks if an anchor with the given ID exists.
  bool hasAnchor(String anchorId) {
    return _anchors.containsKey(anchorId);
  }

  /// Resolves a start frame from an anchor ID with offset.
  ///
  /// Returns null if the anchor doesn't exist.
  int? resolveStartFrame(String anchorId, {int offset = 0}) {
    final anchor = _anchors[anchorId];
    if (anchor == null) return null;
    return anchor.startFrameWithOffset(offset);
  }

  /// Resolves an end frame from an anchor ID with offset.
  ///
  /// Returns null if the anchor doesn't exist or has no end frame.
  int? resolveEndFrame(String anchorId, {int offset = 0}) {
    final anchor = _anchors[anchorId];
    if (anchor == null) return null;
    return anchor.endFrameWithOffset(offset);
  }

  /// Clears all registered anchors.
  void clear() {
    if (_anchors.isNotEmpty) {
      _anchors.clear();
      notifyListeners();
    }
  }
}
