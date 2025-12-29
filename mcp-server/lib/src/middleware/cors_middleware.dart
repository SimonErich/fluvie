import 'package:shelf/shelf.dart';

/// CORS headers for cross-origin requests
const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-API-Key',
  'Access-Control-Max-Age': '86400',
};

/// Creates CORS middleware for handling cross-origin requests
Middleware corsMiddleware() {
  return createMiddleware(
    requestHandler: (Request request) {
      // Handle preflight OPTIONS requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (Response response) {
      // Add CORS headers to all responses
      return response.change(
        headers: {...response.headers, ..._corsHeaders},
      );
    },
  );
}
