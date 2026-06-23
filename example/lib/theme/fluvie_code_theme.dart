import 'package:flutter/painting.dart';

import 'package:fluvie_example/theme/fluvie_colors.dart';

/// The editor syntax theme, ported from the landing page's code cards, for
/// `flutter_highlight` / `CodeThemeData`.
///
/// Maps the Dart grammar's token classes to the brand code colors over the dark
/// code surface; unmapped tokens inherit `root`.
const Map<String, TextStyle> fluvieCodeTheme = {
  'root': TextStyle(backgroundColor: FluvieColors.dark, color: FluvieColors.codeText),
  'keyword': TextStyle(color: FluvieColors.codeKeyword),
  'built_in': TextStyle(color: FluvieColors.codeType),
  'type': TextStyle(color: FluvieColors.codeType),
  'class': TextStyle(color: FluvieColors.codeType),
  'title': TextStyle(color: FluvieColors.codeFunction),
  'function': TextStyle(color: FluvieColors.codeFunction),
  'string': TextStyle(color: FluvieColors.codeString),
  'number': TextStyle(color: FluvieColors.codeNumber),
  'literal': TextStyle(color: FluvieColors.codeNumber),
  'comment': TextStyle(color: FluvieColors.codeComment),
  'meta': TextStyle(color: FluvieColors.codeComment),
};
