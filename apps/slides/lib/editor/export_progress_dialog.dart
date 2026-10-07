import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// The live state of one export run, as the progress dialog shows it.
sealed class ExportStatus {
  const ExportStatus(this.message);

  /// The line the dialog prints.
  final String message;
}

/// The export is running; [message] is the current phase.
final class ExportRunning extends ExportStatus {
  /// Reports a running phase.
  const ExportRunning(super.message);
}

/// The export finished; [message] says where the artifact went.
final class ExportDone extends ExportStatus {
  /// Reports success.
  const ExportDone(super.message);
}

/// The export failed; [message] carries the error.
final class ExportFailed extends ExportStatus {
  /// Reports the failure.
  const ExportFailed(super.message);
}

/// One dialog for every export flow: the live phase line while the run is
/// in flight, then the outcome with a Close action.
final class ExportProgressDialog extends StatelessWidget {
  /// Shows [status] under [title]; [onClose] dismisses once the run ended.
  const ExportProgressDialog({
    required this.title,
    required this.status,
    required this.onClose,
    this.onCancel,
    this.allowBackground = false,
    super.key,
  });

  /// The dialog heading ("Export video", "Export slide images").
  final String title;

  /// The run's live status.
  final ValueListenable<ExportStatus> status;

  /// Dismisses the dialog.
  final VoidCallback onClose;

  /// Cancels a queued video export through its renderer.
  final VoidCallback? onCancel;

  /// Lets an export continue while the author returns to editing.
  final bool allowBackground;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ExportStatus>(
    valueListenable: status,
    builder: (context, state, _) => OiDialog.standard(
      label: title,
      title: title,
      content: OiLabel.body(state.message),
      actions: [
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (state is ExportRunning && onCancel != null)
                OiButton.secondary(label: 'Cancel render', onTap: onCancel),
              if (state is ExportRunning && allowBackground)
                OiButton.primary(label: 'Continue editing', onTap: onClose),
              if (state is! ExportRunning) OiButton.primary(label: 'Close', onTap: onClose),
            ],
          ),
        ),
      ],
      onClose: onClose,
    ),
  );
}
