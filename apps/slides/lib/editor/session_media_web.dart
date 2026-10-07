import 'package:slides/editor/session_sources.dart';

/// The platform default on the web: bytes stay in memory (the browser has no
/// file system), exactly the pure [memorySessionMaterializer].
SessionMaterializer platformSessionMaterializer() => memorySessionMaterializer;
