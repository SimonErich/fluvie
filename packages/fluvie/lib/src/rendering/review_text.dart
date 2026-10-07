import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/captions/runtime/caption_cue_view.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Inspects laid-out Flutter text at one captured frame.
///
/// Findings report paragraph overflow, a declared timing window too short for
/// whitespace-separated words (three words/second plus 350 ms), and requested
/// font families absent from [bundledFonts]. Font absence is a portability risk,
/// not proof of glyph substitution. Custom painters and rasterized text are
/// outside this inspection. Hidden offstage and zero-opacity subtrees are skipped.
List<Map<String, Object?>> inspectRenderedText({
  required GlobalKey boundaryKey,
  required int frame,
  required int fps,
  required int totalFrames,
  required Set<String> bundledFonts,
}) {
  if (fps < 1 || totalFrames < 1) throw ArgumentError('Text review needs a positive timeline.');
  final context = boundaryKey.currentContext;
  if (context is! Element) throw StateError('Text review requires a mounted capture boundary.');
  final findings = <Map<String, Object?>>[];
  void visit(Element element) {
    final render = element is RenderObjectElement ? element.renderObject : null;
    if (render is RenderOffstage && render.offstage ||
        render is RenderOpacity && render.opacity == 0) {
      return;
    }
    if (render is RenderParagraph && render.hasSize) {
      final text = render.text.toPlainText();
      if (text.trim().isNotEmpty) {
        final scope = element.getInheritedWidgetOfExactType<TimeScopeProvider>()?.scope;
        CaptionCueView? caption;
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget case final CaptionCueView view) {
            caption = view;
            return false;
          }
          return true;
        });
        final start = caption?.cue.start.resolveFrames(caption!.scope) ?? scope?.startFrame ?? 0;
        final end =
            caption?.cue.end.resolveFrames(caption!.scope) ??
            start + (scope?.durationFrames ?? totalFrames);
        final common = <String, Object?>{
          'severity': 'warning',
          'frame': frame,
          'startFrame': start,
          'endFrame': end,
          'text': text.length > 240 ? '${text.substring(0, 240)}…' : text,
        };
        void add(String code, String message, String remedy) {
          findings.add({...common, 'code': code, 'message': message, 'remedy': remedy});
        }

        final boxes = render.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        );
        if (render.didExceedMaxLines ||
            boxes.any(
              (box) =>
                  box.left < -0.5 ||
                  box.top < -0.5 ||
                  box.right > render.size.width + 0.5 ||
                  box.bottom > render.size.height + 0.5,
            )) {
          add(
            'text_overflow',
            'Text exceeds its laid-out paragraph or maximum line count.',
            'Increase the text area, reduce the font size or split the caption into shorter lines.',
          );
        }
        final words = text.trim().split(RegExp(r'\s+')).length;
        final minimum = words / 3 + 0.35;
        final available = (end - start) / fps;
        if (available < minimum) {
          add(
            'text_too_brief',
            'The declared window allows ${available.toStringAsFixed(2)} seconds '
                'for $words words; the review heuristic needs ${minimum.toStringAsFixed(2)}.',
            'Lengthen this element or scene, shorten the text or allow this finding for an intentional flash.',
          );
        }
        final families = <String>{};
        void fonts(InlineSpan span) {
          final family = span.style?.fontFamily;
          if (family != null) families.add(family);
          if (span is TextSpan) span.children?.forEach(fonts);
        }

        fonts(render.text);
        for (final family in families.difference(bundledFonts)) {
          add(
            'font_not_bundled',
            'Requested font "$family" is absent from the loaded font manifest.',
            'Declare and bundle this font in pubspec.yaml, or allow intentional host font fallback.',
          );
        }
      }
    }
    element.visitChildren(visit);
  }

  visit(context);
  return findings;
}
