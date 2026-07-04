/// Authors a `VideoSpec` from a natural-language prompt.
///
/// The [FakeAiClient] scripts the model reply, so the flow needs no key and no
/// network. The model runs only at authoring time; its output is a
/// deterministic spec, and rendering that spec never calls a model. Swapping
/// in a real client is one constructor call; see the comment at the end of
/// `main`.
///
/// fluvie_ai builds on `package:fluvie` (a Flutter library), so run this from
/// a Flutter app or a widget test rather than with plain `dart run`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fluvie_ai/fluvie_ai.dart';

Future<void> main() async {
  const scriptedReply =
      '{"fluvieSpec":1,"size":"square","fps":30,"scenes":[{"duration":"2s",'
      '"children":[{"type":"Text","text":"Hello","animate":[{"preset":"fadeIn"}]}]}]}';
  final client = FakeAiClient([scriptedReply]);
  final author = LlmVideoAuthorService(client: client);

  final spec = await author.author('a square title card that says Hello');

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(spec.toJson()));

  // The real clients implement the same AiClient contract, so this is the
  // whole swap (the key comes from ANTHROPIC_API_KEY):
  //
  //   final author = LlmVideoAuthorService(
  //     client: aiClientFromEnv(Platform.environment),
  //   );
}
