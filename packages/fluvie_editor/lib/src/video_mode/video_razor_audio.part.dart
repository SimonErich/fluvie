part of 'video_razor.dart';

void _splitAudio(
  Map<String, Object?> element,
  Map<String, Object?> head,
  Map<String, Object?> tail,
  int cut,
  int length,
  int fps,
) {
  if (element['type'] != 'Clip') return;
  final sliced = splitClipAudio(element: element, cutFrame: cut, windowFrames: length, fps: fps);
  void patch(Map<String, Object?> json, Map<String, Object?> values) {
    for (final entry in values.entries) {
      if (entry.value == null) {
        json.remove(entry.key);
      } else {
        json[entry.key] = entry.value;
      }
    }
  }

  patch(head, sliced.head);
  patch(tail, sliced.tail);
}
