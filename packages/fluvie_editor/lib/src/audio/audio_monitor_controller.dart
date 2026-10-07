import 'package:flutter/foundation.dart';

/// Monitoring-only solo state. Never part of document JSON, history or exports.
final class AudioMonitorController extends ChangeNotifier {
  final Set<String> _solo = {};

  /// The lanes currently being auditioned.
  Set<String> get soloLaneIds => Set.unmodifiable(_solo);

  /// Whether [id] is soloed.
  bool isSoloed(String id) => _solo.contains(id);

  /// Changes one lane's audition state without touching the document.
  void toggleSolo(String id) {
    if (!_solo.remove(id)) _solo.add(id);
    notifyListeners();
  }

  /// Monitoring multiplier; exports deliberately never consult this value.
  double gainForLane(String? id) => _solo.isEmpty || _solo.contains(id) ? 1 : 0;

  /// Restores the full monitor mix.
  void clearSolo() {
    if (_solo.isEmpty) return;
    _solo.clear();
    notifyListeners();
  }
}
