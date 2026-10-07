import 'dart:typed_data';

import 'package:slides/editor/session_media_store.dart';

/// Web: dropped bytes register in the session media store and the spec
/// references them with a `bundle` source — live preview resolves through
/// the published `BundleMedia` scope, and a bundle save packs the bytes.
/// Throws a [SessionMediaBudgetError] past the session budget.
Future<Map<String, Object?>> materializeDroppedMedia(String name, List<int> bytes) async {
  final value = await sessionMediaStore.register(name, Uint8List.fromList(bytes));
  return {'kind': 'bundle', 'value': value};
}
