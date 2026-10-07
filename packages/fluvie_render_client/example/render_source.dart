// #docregion render-source
import 'package:fluvie_render_client/fluvie_render_client.dart';

/// Sends authored Dart to an already configured render service.
Future<RenderJobView> renderSource(ApiRenderClient client, String dartSource) =>
    client.renderAndWait(
      ApiRenderRequest.code(dartSource, quality: 'high', poster: '3s'),
    );
// #enddocregion render-source
