import 'package:cli_quickstart/services/output_probe_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The quickstart preview state: the render command to copy and the current
/// output-file status.
class PreviewState {
  /// Creates a preview state.
  const PreviewState({required this.command, this.output, this.checking = false});

  /// The full `fluvie render` command the user runs.
  final String command;

  /// The rendered output found on disk, or null when it does not exist yet.
  final RenderOutput? output;

  /// True while a probe is in flight.
  final bool checking;

  /// Whether an output file has been found.
  bool get hasOutput => output != null;
}

/// Drives the preview screen: builds the render command and probes the output.
class PreviewViewModel extends Notifier<PreviewState> {
  @override
  PreviewState build() {
    final probe = ref.watch(outputProbeServiceProvider);
    return PreviewState(
      command: 'dart run fluvie_cli:fluvie render whisker_standup --out ${probe.outputPath}',
    );
  }

  /// Re-checks whether the output MP4 has been rendered.
  Future<void> refresh() async {
    state = PreviewState(command: state.command, output: state.output, checking: true);
    final output = await ref.read(outputProbeServiceProvider).probe();
    state = PreviewState(command: state.command, output: output);
  }
}

/// The preview view-model provider.
final NotifierProvider<PreviewViewModel, PreviewState> previewViewModelProvider =
    NotifierProvider<PreviewViewModel, PreviewState>(PreviewViewModel.new);
