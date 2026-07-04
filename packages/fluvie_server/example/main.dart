/// Renders a video through a Fluvie render server.
///
/// This is the web-safe client (`package:fluvie_server/client.dart`): it
/// depends only on `package:http`, so the same calls work in a browser, on
/// mobile, and on the desktop. Start a server first (see `example/README.md`),
/// then: `dart run example/main.dart http://localhost:8080`.
library;

import 'dart:io';

import 'package:fluvie_server/client.dart';

Future<void> main(List<String> args) async {
  final client = ApiRenderClient(
    baseUrl: Uri.parse(args.isEmpty ? 'http://localhost:8080' : args.first),
    apiToken: Platform.environment['FLUVIE_API_TOKEN'],
  );

  // Send a serialized VideoSpec; the server captures the frames and encodes
  // the MP4. `ApiRenderRequest.key` (a registered composition) and `.prompt`
  // (author with a model, then render) are the other two entry points.
  final job = await client.renderAndWait(
    ApiRenderRequest.spec(const {
      'fluvieSpec': 1,
      'size': 'square',
      'fps': 30,
      'scenes': [
        {
          'duration': '2s',
          'children': [
            {
              'type': 'Text',
              'text': 'Hello from the server',
              'animate': [
                {'preset': 'fadeIn'},
              ],
            },
          ],
        },
      ],
    }),
    onUpdate: (job) => stdout.writeln('${job.status} ${job.completed ?? 0}/${job.total ?? 0}'),
  );

  stdout.writeln('done: ${job.video?.downloadUrl}');
}
