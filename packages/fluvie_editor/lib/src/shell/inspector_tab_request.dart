import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/shell/inspector_tabs.dart';

/// One explicit request to reveal an inspector panel, even if the previous
/// request named the same tab and the author navigated away in between.
final class InspectorTabRequest {
  /// Requests [tab]. Identity makes repeated requests distinct events.
  InspectorTabRequest(this.tab);

  /// The panel to reveal.
  final InspectorTab tab;
}

/// Dispatches non-document navigation from timeline gestures.
final class InspectorTabRequestController extends Notifier<InspectorTabRequest?> {
  @override
  InspectorTabRequest? build() => null;

  /// Reveals [tab] once; subsequent manual tab picks stay in control.
  void reveal(InspectorTab tab) => state = InspectorTabRequest(tab);
}

/// The latest inspector navigation intent for the mounted editor.
final inspectorTabRequestProvider =
    NotifierProvider<InspectorTabRequestController, InspectorTabRequest?>(
      InspectorTabRequestController.new,
    );
