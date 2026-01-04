# Fluvie MCP Agent

The Fluvie MCP (Model Context Protocol) server provides AI assistants with direct access to Fluvie documentation, code generation, and template suggestions.

## Overview

The MCP server enables AI tools like Claude Desktop, VS Code extensions, and other MCP-compatible clients to:

- **Search Documentation** - Find relevant widgets, patterns, and examples
- **Generate Code** - Create Fluvie compositions from natural language
- **Suggest Templates** - Get template recommendations for your use case
- **Access References** - Get detailed widget and template documentation

**Public Server**: `https://mcp.fluvie.dev`

---

## Quick Setup

### Claude Desktop

1. Open Claude Desktop settings
2. Navigate to MCP Servers configuration
3. Add the Fluvie server:

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

4. Restart Claude Desktop
5. Ask Claude to help create Fluvie videos!

### VS Code with Continue.dev

1. Install the Continue extension
2. Open Continue settings (`~/.continue/config.json`)
3. Add the MCP server:

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.dev/mcp"
    }
  }
}
```

4. Reload VS Code

---

## Available Tools

### 1. searchDocs

Search Fluvie documentation with intelligent ranking.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |
| `category` | string | No | Filter by category (widgets, templates, effects, etc.) |
| `limit` | number | No | Max results (default: 10) |

**Example prompt:**
> "Search the Fluvie docs for how to animate text opacity"

**Returns:**
- Relevant documentation sections
- Code snippets
- Related widget references

### 2. getTemplate

Get detailed template information and usage examples.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `category` | string | Yes | Template category |
| `name` | string | Yes | Template name |

**Categories:** intro, ranking, data_viz, collage, thematic, conclusion

**Example prompt:**
> "Get the details for TheNeonGate intro template"

**Returns:**
- Template description
- Required data fields
- Optional properties
- Complete code example

### 3. suggestTemplates

Get template recommendations based on your use case.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `useCase` | string | Yes | What you want to create |
| `contentType` | string | No | Type of content (photos, stats, text, mixed) |
| `mood` | string | No | Desired mood (dramatic, calm, energetic, nostalgic, modern) |

**Example prompt:**
> "Suggest Fluvie templates for a year-end music review with dramatic feel"

**Returns:**
- Ranked template suggestions
- Match scores
- Brief descriptions

### 4. getWidgetReference

Get complete widget documentation.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `widgetName` | string | Yes | Name of the widget |

**Example prompt:**
> "Get the reference for the AnimatedProp widget"

**Returns:**
- Widget description
- All properties with types
- Code examples
- Related widgets

### 5. generateCode

Generate Fluvie code from natural language descriptions.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `description` | string | Yes | What you want to create |
| `type` | string | No | Output type: scene, video, widget (default: scene) |
| `fps` | number | No | Frames per second (default: 30) |
| `aspectRatio` | string | No | Aspect ratio: 16:9, 9:16, 1:1 (default: 16:9) |

**Example prompt:**
> "Generate code for an animated title with sparkles that fades in over 2 seconds"

**Returns:**
- Complete, runnable Dart code
- Comments explaining the structure
- Import statements

---

## Resources

The MCP server also provides these resources:

### fluvie://docs/ai-reference

Complete AI-readable documentation in a single markdown file. Contains all widgets, templates, effects, and examples.

### fluvie://templates

JSON catalog of all 30 templates with metadata.

---

## Example Conversations

### Creating a Simple Scene

**You:** "Create a Fluvie scene with animated text that says 'Welcome' with a fade in effect"

**Claude with MCP:** Uses `generateCode` to create:

```dart
import 'package:fluvie/declarative.dart';

final scene = Scene(
  durationInFrames: 90, // 3 seconds at 30fps
  children: [
    VCenter(
      child: FadeText(
        text: 'Welcome',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        fadeInFrames: 30,
      ),
    ),
  ],
);
```

### Finding the Right Template

**You:** "I want to create a Spotify Wrapped style video showing my top 5 songs"

**Claude with MCP:** Uses `suggestTemplates` with useCase="ranking" and finds:

> "For a top 5 ranking video, I recommend **StackClimb** - it reveals items from bottom to top with stacking cards, perfect for countdowns. Here's how to use it..."

### Learning Widget Usage

**You:** "How do I use AnimatedProp to animate multiple properties?"

**Claude with MCP:** Uses `getWidgetReference` and `searchDocs` to explain:

> "AnimatedProp drives animations using PropAnimation. For multiple properties, use `PropAnimation.combine()`. Here's an example..."

---

## Self-Hosting

If you prefer to run your own MCP server:

### Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/simonerich/fluvie.git
cd fluvie/mcp-server

# Configure
cp .env.example .env
# Edit .env as needed

# Run
docker-compose up -d
```

### Manual

```bash
cd fluvie/mcp-server

# Install dependencies
dart pub get

# Run
dart run bin/server.dart
```

Configure your MCP client to use `http://localhost:8080/mcp`

See [setup.md](setup.md) for detailed self-hosting instructions.

---

## Related

- [IDE Integration Guide](ide-integration.md) - Detailed setup for various IDEs
- [Setup Guide](setup.md) - Self-hosting and configuration
- [IDE Helpers](../ide-helpers/README.md) - Using AI reference file directly
