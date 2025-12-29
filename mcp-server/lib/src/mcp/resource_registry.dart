import 'mcp_types.dart';

/// Registry for MCP resources
class ResourceRegistry {
  final List<ResourceDefinition> _resources = [];

  /// Add a resource definition
  void addResource(ResourceDefinition resource) {
    _resources.add(resource);
  }

  /// List all registered resources
  List<Map<String, dynamic>> listResources() {
    return _resources.map((r) => r.toJson()).toList();
  }

  /// Find a resource that matches the given URI
  ResourceDefinition? findResource(String uri) {
    for (final resource in _resources) {
      if (_matchesUri(resource.uri, uri)) {
        return resource;
      }
    }
    return null;
  }

  /// Read a resource by URI
  Future<String> readResource(String uri) async {
    final resource = findResource(uri);
    if (resource == null) {
      throw McpError('Resource not found: $uri', code: -32601);
    }

    final params = _extractParams(resource.uri, uri);
    return resource.handler(uri, params);
  }

  /// Check if a URI matches a pattern (supports {param} placeholders)
  bool _matchesUri(String pattern, String uri) {
    final patternParts = pattern.split('/');
    final uriParts = uri.split('/');

    if (patternParts.length != uriParts.length) {
      return false;
    }

    for (var i = 0; i < patternParts.length; i++) {
      final patternPart = patternParts[i];
      final uriPart = uriParts[i];

      if (patternPart.startsWith('{') && patternPart.endsWith('}')) {
        // This is a parameter placeholder, matches anything
        continue;
      }

      if (patternPart != uriPart) {
        return false;
      }
    }

    return true;
  }

  /// Extract parameters from a URI based on a pattern
  Map<String, String> _extractParams(String pattern, String uri) {
    final params = <String, String>{};
    final patternParts = pattern.split('/');
    final uriParts = uri.split('/');

    for (var i = 0; i < patternParts.length && i < uriParts.length; i++) {
      final patternPart = patternParts[i];
      if (patternPart.startsWith('{') && patternPart.endsWith('}')) {
        final paramName = patternPart.substring(1, patternPart.length - 1);
        params[paramName] = uriParts[i];
      }
    }

    return params;
  }

  /// Get the number of registered resources
  int get count => _resources.length;
}
