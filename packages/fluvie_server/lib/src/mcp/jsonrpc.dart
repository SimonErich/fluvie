/// JSON-RPC 2.0 helpers for the MCP transport.
///
/// MCP speaks JSON-RPC 2.0. These helpers build the response envelopes and name
/// the standard error codes so the server engine reads cleanly.
library;

/// The error code for a malformed request object.
const int jsonRpcInvalidRequest = -32600;

/// The error code for an unknown method.
const int jsonRpcMethodNotFound = -32601;

/// The error code for invalid method parameters.
const int jsonRpcInvalidParams = -32602;

/// Builds a JSON-RPC success envelope for request [id] carrying [result].
Map<String, Object?> jsonRpcResult(Object? id, Map<String, Object?> result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

/// Builds a JSON-RPC error envelope for request [id] with [code] and [message].
Map<String, Object?> jsonRpcError(Object? id, int code, String message) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': message},
};
