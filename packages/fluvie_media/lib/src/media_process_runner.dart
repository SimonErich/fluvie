/// Text result from a native media process.
typedef MediaProcessResult = ({int exitCode, String stdout, String stderr});

/// Injectable process runner; binary frame data is written to temporary files.
typedef MediaProcessRunner =
    Future<MediaProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
