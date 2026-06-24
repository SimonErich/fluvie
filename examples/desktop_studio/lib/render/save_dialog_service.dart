import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the user where to save the rendered MP4.
///
/// A contract (not a typedef) so the native dialog is replaced by a fake that
/// returns a fixed path in widget and integration tests.
// ignore: one_member_abstracts
abstract interface class SaveDialogService {
  /// Returns the chosen path, or null when the user cancels.
  Future<String?> chooseSavePath(String suggestedName);
}

/// The real dialog, backed by `file_selector`.
class FileSelectorSaveDialogService implements SaveDialogService {
  /// Creates the file-selector dialog service.
  const FileSelectorSaveDialogService();

  @override
  Future<String?> chooseSavePath(String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'MP4 video', extensions: ['mp4']),
      ],
    );
    return location?.path;
  }
}

/// The injected save-dialog service (overridden with a fake in tests).
final Provider<SaveDialogService> saveDialogServiceProvider = Provider<SaveDialogService>(
  (ref) => const FileSelectorSaveDialogService(),
);
