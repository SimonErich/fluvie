// Browser-only glue: exercised by hand and compiled by the web_build CI
// job; tests inject fakes through the seam in `fluvie_file_saver.dart`.
// coverage:ignore-file
import 'dart:convert' show utf8;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data' show Uint8List;

import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:web/web.dart' as web;

/// The web saver: the File System Access API where the browser has it
/// (Save rewrites the picked file silently), a plain download otherwise.
FluvieFileSaver platformFluvieFileSaver() => _WebFluvieFileSaver();

final class _WebFluvieFileSaver implements FluvieFileSaver {
  JSObject? _handle;

  // The browser exposes handles, never paths.
  @override
  String? get targetPath => null;

  bool get _canPickFiles =>
      web.window.getProperty<JSAny?>('showSaveFilePicker'.toJS).isDefinedAndNotNull;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    if (!_canPickFiles) {
      _download(suggestedName, contents);
      return suggestedName;
    }
    var handle = _handle;
    if (pickNew || handle == null) {
      handle = await _pick(suggestedName);
      if (handle == null) return null;
      _handle = handle;
    }
    return _write(handle, suggestedName, contents);
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    if (!_canPickFiles) {
      _download(suggestedName, contents);
      return suggestedName;
    }
    // Always a fresh handle, and the remembered one stays put.
    final handle = await _pick(suggestedName);
    if (handle == null) return null;
    return _write(handle, suggestedName, contents);
  }

  @override
  Future<String?> saveCopyBytes({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    final data = Uint8List.fromList(bytes);
    if (!_canPickFiles) {
      _downloadBytes(suggestedName, data, _mimeFor(suggestedName));
      return suggestedName;
    }
    // Always a fresh handle, and the remembered one stays put.
    final handle = await _pick(suggestedName);
    if (handle == null) return null;
    final writable = await handle.callMethod<JSPromise<JSObject>>('createWritable'.toJS).toDart;
    await writable.callMethod<JSPromise<JSAny?>>('write'.toJS, data.toJS).toDart;
    await writable.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
    return handle.getProperty<JSString?>('name'.toJS)?.toDart ?? suggestedName;
  }

  String _mimeFor(String name) =>
      name.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream';

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async {
    final data = Uint8List.fromList(bytes);
    if (!_canPickFiles) {
      _downloadBytes(suggestedName, data, 'application/zip');
      return suggestedName;
    }
    var handle = _handle;
    if (pickNew || handle == null) {
      handle = await _pick(suggestedName);
      if (handle == null) return null;
      _handle = handle;
    }
    final writable = await handle.callMethod<JSPromise<JSObject>>('createWritable'.toJS).toDart;
    await writable.callMethod<JSPromise<JSAny?>>('write'.toJS, data.toJS).toDart;
    await writable.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
    return handle.getProperty<JSString?>('name'.toJS)?.toDart ?? suggestedName;
  }

  Future<JSObject?> _pick(String suggestedName) async {
    final options = JSObject()..setProperty('suggestedName'.toJS, suggestedName.toJS);
    try {
      return await web.window
          .callMethod<JSPromise<JSObject>>('showSaveFilePicker'.toJS, options)
          .toDart;
    } on Object {
      // AbortError: the user closed the picker.
      return null;
    }
  }

  Future<String> _write(JSObject handle, String suggestedName, String contents) async {
    final writable = await handle.callMethod<JSPromise<JSObject>>('createWritable'.toJS).toDart;
    await writable.callMethod<JSPromise<JSAny?>>('write'.toJS, contents.toJS).toDart;
    await writable.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
    return handle.getProperty<JSString?>('name'.toJS)?.toDart ?? suggestedName;
  }

  void _download(String name, String contents) =>
      _downloadBytes(name, utf8.encode(contents), 'application/json');

  void _downloadBytes(String name, Uint8List bytes, String mimeType) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = name
      ..click();
    web.URL.revokeObjectURL(url);
  }
}
