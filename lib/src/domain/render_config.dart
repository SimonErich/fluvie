import 'package:json_annotation/json_annotation.dart';

part 'render_config.g.dart';

@JsonSerializable()
class RenderConfig {
  final TimelineConfig timeline;
  final List<ClipConfig> clips;

  RenderConfig({
    required this.timeline,
    required this.clips,
  });

  factory RenderConfig.fromJson(Map<String, dynamic> json) =>
      _$RenderConfigFromJson(json);
  Map<String, dynamic> toJson() => _$RenderConfigToJson(this);
}

@JsonSerializable()
class TimelineConfig {
  final int fps;
  final int durationInFrames;
  final int width;
  final int height;

  TimelineConfig({
    required this.fps,
    required this.durationInFrames,
    required this.width,
    required this.height,
  });

  factory TimelineConfig.fromJson(Map<String, dynamic> json) =>
      _$TimelineConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineConfigToJson(this);
}

@JsonSerializable()
class ClipConfig {
  final int startFrame;
  final int durationInFrames;
  final Map<String, dynamic> spatialProps;
  final ClipConfig? child;

  ClipConfig({
    required this.startFrame,
    required this.durationInFrames,
    this.spatialProps = const {},
    this.child,
  });

  factory ClipConfig.fromJson(Map<String, dynamic> json) =>
      _$ClipConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ClipConfigToJson(this);
}
