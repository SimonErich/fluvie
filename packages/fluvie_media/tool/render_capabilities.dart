import 'dart:convert';
import 'dart:io';

import 'package:fluvie_media/fluvie_media.dart';

void main() => stdout.writeln(jsonEncode(RenderCapabilities.registryJson()));
