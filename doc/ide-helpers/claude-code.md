# Claude Code Integration

Guide for using Claude Code CLI with Fluvie projects.

---

## Quick Start

### Option 1: Reference Documentation Directly

```bash
# Navigate to your Fluvie project
cd my-fluvie-project

# Start Claude Code with Fluvie docs
claude --context ../fluvie/doc/FLUVIE_AI_REFERENCE.md
```

### Option 2: Add to Project Context

Create a symlink or copy the reference file:

```bash
# Symlink (keeps updated)
ln -s /path/to/fluvie/doc/FLUVIE_AI_REFERENCE.md ./docs/

# Or copy
cp /path/to/fluvie/doc/FLUVIE_AI_REFERENCE.md ./docs/
```

Then reference in prompts:
> "Using docs/FLUVIE_AI_REFERENCE.md, create a scene with..."

---

## CLAUDE.md Setup

Create a `CLAUDE.md` file in your project root to give Claude Code persistent context:

```markdown
# Fluvie Video Project

## Overview
This project uses the Fluvie declarative video composition library for Flutter.

## Documentation
The complete Fluvie reference is at: doc/FLUVIE_AI_REFERENCE.md

Always read this file when:
- Generating Fluvie code
- Answering questions about widgets
- Suggesting templates or patterns

## Key Concepts

### Frame-Based Timing
Fluvie uses frames, not seconds:
- 30fps: 1 second = 30 frames
- 60fps: 1 second = 60 frames

### Import
Always include: `import 'package:fluvie/declarative.dart';`

### Widget Hierarchy
Video → Scene → Content (VStack, AnimatedProp, etc.)

## Project Structure
```
lib/
  videos/           # Video compositions
  templates/        # Custom templates
  widgets/          # Reusable components
assets/
  images/           # Static images
  videos/           # Video clips
```

## Common Tasks

### Generate a New Scene
1. Read FLUVIE_AI_REFERENCE.md for widget options
2. Calculate frame durations based on fps
3. Use appropriate layout widgets (VCenter, VRow, etc.)
4. Add animations with AnimatedProp

### Use a Template
1. Check template catalog in reference
2. Match data type requirements
3. Customize properties as needed

### Add Effects
1. ParticleEffect for particles (sparkles, confetti)
2. EffectOverlay for post-processing (grain, vignette)
3. Background for scene backgrounds

## Style Guidelines
- Use const constructors
- Calculate frames from seconds explicitly
- Add comments for animation sequences
- Use descriptive names for scenes/widgets
```

---

## Example Prompts

### Creating Scenes

> "Create a Fluvie scene that displays 'Your Year in Music' with a fade-in over 1 second, then shows 3 stat cards staggering in from below"

Claude Code will:
1. Read the reference file
2. Calculate frames (30 frames for 1 second at 30fps)
3. Generate appropriate code with AnimatedProp and StaggerConfig

### Using Templates

> "I want to create a top 5 songs video. Which Fluvie template should I use and generate an example?"

Claude Code will:
1. Recommend StackClimb or TheSpotlight template
2. Show the template usage with RankingData
3. Provide customization options

### Debugging

> "My AnimatedProp animation isn't working. Here's my code: [paste]. What's wrong?"

Claude Code will:
1. Check animation frame ranges
2. Verify PropAnimation usage
3. Ensure proper widget hierarchy

---

## Workflow Examples

### 1. Starting a New Video Project

```bash
# Initialize project
flutter create my_video_app
cd my_video_app

# Add Fluvie dependency
flutter pub add fluvie

# Create CLAUDE.md with project context
claude

# In Claude Code:
> "Read the Fluvie docs and create a basic video structure with an intro scene and a content scene"
```

### 2. Adding Animation

```bash
claude

# In Claude Code:
> "Add an animation to my title that slides in from the left while fading in over 1.5 seconds at 30fps"
```

### 3. Using Templates

```bash
claude

# In Claude Code:
> "Generate a complete year-review video using these templates:
> - TheNeonGate for intro
> - StackClimb for top songs
> - TheSummaryPoster for conclusion"
```

---

## Tips for Better Results

### 1. Be Specific About Timing

```
❌ "Add a fade animation"
✅ "Add a 1-second fade animation at 30fps (30 frames)"
```

### 2. Reference the Documentation

```
❌ "Create a stats display"
✅ "Using the StatCard helper from the reference, create a stats display"
```

### 3. Describe Visual Goals

```
❌ "Animate the text"
✅ "Animate the text to slide up from below while scaling from 80% to 100%"
```

### 4. Specify Output Format

```
❌ "Generate code"
✅ "Generate a complete Scene widget that I can add to my Video"
```

---

## Combining with MCP

For the best experience, use both approaches:

1. **MCP Server** - For interactive documentation queries
2. **AI Reference File** - For code generation context

Setup:
```bash
# Configure MCP in Claude Desktop
# Then use Claude Code with reference file

claude --context doc/FLUVIE_AI_REFERENCE.md
```

Now you have:
- MCP tools for searching and suggestions
- Full documentation context for code generation

---

## Troubleshooting

### "Context too long"

The reference file is optimized for size, but if needed:
- Reference specific sections instead of the whole file
- Use MCP server for queries, file for generation

### "Wrong widget used"

- Ensure the reference file is in context
- Be explicit: "Use VCenter, not Center"
- Reference the V-prefix convention

### "Animation not working"

Ask Claude to:
- Check frame calculations
- Verify startFrame < endFrame
- Ensure AnimatedProp wraps the content

---

## Related

- [IDE Helpers Overview](README.md)
- [Cursor Rules](cursor-rules.md)
- [MCP Server](../mcp-agent/README.md)
