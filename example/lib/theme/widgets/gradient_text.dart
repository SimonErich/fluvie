import 'package:flutter/widgets.dart';
import 'package:fluvie_example/theme/fluvie_gradients.dart';

/// Text painted with the brand [FluvieGradients.primary] gradient via a
/// [ShaderMask]. Used for the app wordmark and section headings.
final class GradientText extends StatelessWidget {
  /// Creates gradient-filled text from [data], styled by [style].
  const GradientText(this.data, {this.style, this.textAlign, super.key});

  /// The string to paint.
  final String data;

  /// The text style; its color is replaced by the gradient.
  final TextStyle? style;

  /// How to align the text horizontally.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: FluvieGradients.primary.createShader,
      child: Text(
        data,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(color: const Color(0xFFFFFFFF)),
      ),
    );
  }
}
