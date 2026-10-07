import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  test('automation corpus round-trips and pins its render digest', () {
    final spec = VideoSpec.fromJson(
      jsonDecode(File('test/serialization/corpus/audio_automation.fluvie.json').readAsStringSync())
          as Map<String, Object?>,
    );
    expect(VideoSpec.fromJson(spec.toJson()).digest(), spec.digest());
    expect(spec.digest(), '5756835653afcbde');
  });
}
