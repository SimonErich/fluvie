# IDE Integration Guide

Configure various IDEs and AI tools to use the Fluvie MCP server.

---

## Claude Desktop

### Configuration

1. Open Claude Desktop
2. Go to **Settings** → **Developer** → **MCP Servers**
3. Click **Add Server**
4. Enter configuration:

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.dev/mcp",
      "transport": "http"
    }
  }
}
```

On macOS, the config file is at:
`~/Library/Application Support/Claude/claude_desktop_config.json`

On Windows:
`%APPDATA%\Claude\claude_desktop_config.json`

### Usage

After configuration, Claude can:

- Generate Fluvie code from descriptions
- Search documentation
- Suggest templates
- Explain widget usage

**Example prompts:**

> "Create a Fluvie scene with an animated title and sparkle effects"

> "What's the best template for showing a top 10 ranking?"

> "How do I use AnimatedProp to fade in text over 2 seconds?"

---

## VS Code with Continue

### Installation

1. Install [Continue extension](https://marketplace.visualstudio.com/items?itemName=Continue.continue)
2. Open command palette: `Cmd/Ctrl + Shift + P`
3. Run: `Continue: Open Config File`

### Configuration

Add to `~/.continue/config.json`:

```json
{
  "models": [...],
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.dev/mcp"
    }
  }
}
```

### Usage

1. Open Continue sidebar (`Cmd/Ctrl + L`)
2. Ask questions about Fluvie
3. Generate code directly in your project

---

## Cursor IDE

### Configuration

1. Open Settings (`Cmd/Ctrl + ,`)
2. Search for "MCP" or "Model Context Protocol"
3. Add server configuration:

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.dev/mcp",
      "transport": "http"
    }
  }
}
```

### Using with Cursor

In Cursor's AI chat or Composer:

> "@fluvie generate a scene with animated stats"

---

## Zed Editor

### Configuration

Add to your Zed settings (`~/.config/zed/settings.json`):

```json
{
  "assistant": {
    "mcp_servers": {
      "fluvie": {
        "url": "https://mcp.fluvie.dev/mcp"
      }
    }
  }
}
```

---

## Generic MCP Client

For any MCP-compatible client, use these settings:

| Setting | Value |
|---------|-------|
| Server URL | `https://mcp.fluvie.dev/mcp` |
| Transport | HTTP |
| SSE Endpoint | `https://mcp.fluvie.dev/mcp/sse` |

### JSON-RPC Example

```bash
curl -X POST https://mcp.fluvie.dev/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }'
```

Response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "searchDocs",
        "description": "Search Fluvie documentation",
        "inputSchema": {...}
      },
      ...
    ]
  }
}
```

---

## Local Development Setup

For developing Fluvie projects with a local MCP server:

### 1. Start Local Server

```bash
cd fluvie/mcp-server
docker-compose up -d
```

### 2. Configure IDE

Replace the URL with your local server:

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

### 3. Advantages

- Faster responses (no network latency)
- Works offline
- Can customize documentation
- Test documentation changes before publishing

---

## Combining with IDE Helpers

For the best experience, combine MCP with the AI reference file:

1. Configure MCP server (for interactive queries)
2. Add `FLUVIE_AI_REFERENCE.md` to project context (for code generation)

See [IDE Helpers](../ide-helpers/README.md) for using the reference file.

---

## Troubleshooting

### "Server not found" error

1. Check server is running: `curl https://mcp.fluvie.dev/health`
2. Verify URL in configuration
3. Restart IDE after changing config

### Tools not appearing

1. Ensure MCP server is enabled in IDE settings
2. Check for errors in IDE console/logs
3. Try reconnecting: disable and re-enable server

### Slow responses

1. Check internet connection
2. Consider self-hosting for lower latency
3. Use local server for development

### "Invalid response" errors

1. Check MCP server logs
2. Verify you're using the correct endpoint (`/mcp`)
3. Update IDE/extension to latest version

---

## Next Steps

- [MCP Agent Overview](README.md) - Learn about available tools
- [Setup Guide](setup.md) - Self-host the server
- [IDE Helpers](../ide-helpers/README.md) - Use AI reference file
