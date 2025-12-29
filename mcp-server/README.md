# Fluvie MCP Server

Model Context Protocol server for the Fluvie video composition library. Provides AI-powered documentation search, code generation, and template suggestions.

## Quick Start

### Local Development

```bash
# Install dependencies
dart pub get

# Run the server
dart run bin/server.dart
```

Server starts at `http://localhost:8080`

### Docker

```bash
# Build and run
docker-compose up -d

# With HTTPS (Traefik)
docker-compose --profile with-proxy up -d
```

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API documentation |
| `/health` | GET | Health check |
| `/mcp` | POST | MCP JSON-RPC endpoint |
| `/mcp/sse` | GET | Server-Sent Events stream |
| `/resources/{path}` | GET | Resource access |

## MCP Tools

### searchDocs

Search Fluvie documentation with TF-IDF ranking.

```json
{
  "query": "animate text opacity",
  "category": "widgets",
  "limit": 5
}
```

### getTemplate

Get detailed information about a template.

```json
{
  "category": "intro",
  "name": "TheNeonGate"
}
```

### suggestTemplates

Get template recommendations based on use case.

```json
{
  "useCase": "year-end summary",
  "contentType": "stats",
  "mood": "dramatic"
}
```

### getWidgetReference

Get widget documentation and examples.

```json
{
  "widgetName": "AnimatedProp"
}
```

### generateCode

Generate Fluvie code from natural language.

```json
{
  "description": "Create an intro with a neon portal effect",
  "type": "scene",
  "fps": 30,
  "aspectRatio": "16:9"
}
```

## MCP Resources

| URI | Description |
|-----|-------------|
| `fluvie://docs/ai-reference` | Complete AI reference documentation |
| `fluvie://templates` | Template catalog JSON |

## Client Configuration

### Claude Desktop

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.at/mcp",
      "transport": "http"
    }
  }
}
```

### VS Code (Continue.dev)

```json
{
  "models": [...],
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.at/mcp"
    }
  }
}
```

### Self-Hosted

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "http://localhost:8080/mcp",
      "transport": "http"
    }
  }
}
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
# Server port
PORT=8080

# Documentation path
DOCS_PATH=../doc

# Logging level
LOG_LEVEL=info
```

## Deployment

### Production with Docker

```bash
# Build production image
docker build -t fluvie-mcp:latest .

# Run with documentation volume
docker run -d \
  -p 8080:8080 \
  -v /path/to/docs:/app/data/docs:ro \
  --name fluvie-mcp \
  fluvie-mcp:latest
```

### With Traefik (HTTPS)

```bash
# Set your email for Let's Encrypt
export ACME_EMAIL=you@example.com

# Start with proxy profile
docker-compose --profile with-proxy up -d
```

## Development

### Project Structure

```
mcp-server/
├── bin/server.dart           # Main entry point
├── lib/
│   ├── mcp_server.dart       # Library exports
│   └── src/
│       ├── config/           # Server configuration
│       ├── mcp/              # MCP protocol handling
│       ├── tools/            # MCP tool implementations
│       ├── indexing/         # Documentation indexer
│       └── middleware/       # HTTP middleware
├── data/docs/                # Documentation files
├── Dockerfile
└── docker-compose.yml
```

### Adding a New Tool

1. Create tool file in `lib/src/tools/`
2. Implement the tool function
3. Register in `bin/server.dart`

```dart
// lib/src/tools/my_tool.dart
ToolDefinition createMyTool() {
  return ToolDefinition(
    name: 'myTool',
    description: 'My custom tool',
    inputSchema: {...},
    handler: (args) async {
      // Implementation
      return {'result': 'data'};
    },
  );
}
```

## License

MIT License - See LICENSE file for details.
