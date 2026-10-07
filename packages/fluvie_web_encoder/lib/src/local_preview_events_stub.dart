/// Listens for completed local preview rebuilds. Returns a function to stop.
void Function() watchLocalPreviewReloads({
  required Uri endpoint,
  required String sessionToken,
  void Function()? onReload,
}) => throw UnsupportedError('Local preview reload events require a browser.');
