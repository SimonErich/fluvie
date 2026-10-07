import 'package:fluvie_ai/src/client/ai_client.dart';

/// Shared transport budget, checked before image decoding or network work.
void checkEvidenceImageLimits(Iterable<AiImage> images) {
  if (images.length > 4 || images.any((image) => image.bytes.length > 4 * 1024 * 1024)) {
    throw AiClientException('Select at most four visual references of up to 4 MiB each.');
  }
}
