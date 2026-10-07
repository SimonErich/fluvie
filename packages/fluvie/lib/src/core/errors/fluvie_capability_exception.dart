import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// A host cannot prepare a capability required by an authored composition.
final class FluvieCapabilityException extends FluvieRenderException {
  /// Names the unsupported capability and the host that needs an adapter.
  FluvieCapabilityException({required this.capability, required this.host, required String remedy})
    : super('$capability is unavailable in $host. $remedy');

  /// The missing preparation capability, suitable for host error UIs.
  final String capability;

  /// The active platform or host description.
  final String host;
}
