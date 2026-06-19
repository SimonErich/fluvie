import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

/// What the "Generate with AI" panel binds to: whether authoring is in flight,
/// the last error, and the authored spec.
final class GenerateState {
  /// Creates a snapshot; the initial state is idle, error-free, and spec-less.
  const GenerateState({this.busy = false, this.error, this.spec});

  /// True while the model is authoring; the Generate button disables itself.
  final bool busy;

  /// The last authoring error message, or null.
  final String? error;

  /// The most recently authored spec, or null before the first success.
  final VideoSpec? spec;
}

/// Drives [VideoAuthorService] for the prompt panel: one authoring run at a
/// time, surfacing the validated spec or the error.
///
/// The model lives behind `videoAuthorServiceProvider` (overridden with a fake
/// in tests, or a real provider built from the environment in the app), so this
/// view model never touches the network directly.
final class GenerateViewModel extends Notifier<GenerateState> {
  @override
  GenerateState build() => const GenerateState();

  /// Authors a spec from [prompt]; a no-op while busy or for an empty prompt.
  Future<void> generate(String prompt) async {
    final trimmed = prompt.trim();
    if (state.busy || trimmed.isEmpty) return;
    state = const GenerateState(busy: true);
    try {
      final service = ref.read(videoAuthorServiceProvider);
      final spec = await service.author(trimmed);
      if (!ref.mounted) return;
      state = GenerateState(spec: spec);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = GenerateState(error: '$error');
    }
  }
}

/// The generate view model and its state.
final generateViewModelProvider = NotifierProvider<GenerateViewModel, GenerateState>(
  GenerateViewModel.new,
);
