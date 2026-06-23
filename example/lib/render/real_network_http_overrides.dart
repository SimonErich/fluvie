import 'dart:io';

/// An [HttpOverrides] that restores real networking inside `flutter test`.
///
/// `flutter_test`'s `TestWidgetsFlutterBinding` installs a global
/// [HttpOverrides] whose client answers every request with HTTP 400 and never
/// touches the network, so a test cannot accidentally hit a server. The capture
/// harness runs the `fluvie generate`/`edit` authoring step under that binding,
/// and that step is the one place that must reach a real LLM endpoint.
///
/// This subclass overrides nothing, so it inherits [HttpOverrides]'s concrete
/// default `createHttpClient`, which returns a real `HttpClient`. Run the
/// authoring call inside [HttpOverrides.runWithHttpOverrides] with an instance
/// of this class: the zone-local override takes precedence over the binding's
/// global mock, so any client built there is a real one.
///
/// The client must be *constructed* inside the zone — `package:http` builds its
/// `HttpClient` in its constructor, and `HttpClient()` resolves the active
/// override at construction time — which is why the whole authoring body, not
/// just the request, runs under the zone.
class RealNetworkHttpOverrides extends HttpOverrides {}
