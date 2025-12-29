// ==================== MONACO EDITOR INTEGRATION ====================

// Code examples for the playground
const codeExamples = {
  'hello-fluvie': `import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  final composition = VideoComposition(
    fps: 30,
    durationInFrames: 90, // 3 seconds
    width: 1920,
    height: 1080,
    child: LayerStack(
      children: [
        // Background gradient layer
        Layer.background(
          fadeInFrames: 15,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0175C2), // Flutter blue
                  Color(0xFF7C4DFF), // Purple
                ],
              ),
            ),
          ),
        ),

        // Animated text layer
        Layer(
          id: 'title',
          startFrame: 15,
          endFrame: 75,
          fadeInFrames: 15,
          fadeOutFrames: 15,
          child: Center(
            child: TimeConsumer(
              builder: (context, frame, progress) {
                return Transform.scale(
                  scale: 0.5 + (progress * 0.5), // Scale from 50% to 100%
                  child: Text(
                    'Hello Fluvie!',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );

  // Render the video
  final renderService = RenderService();
  final output = await renderService.execute(
    config: composition.toRenderConfig(),
    onFrameUpdate: (frame) {
      print('Rendering frame $frame/90');
    },
  );

  print('Video saved to: $output');
}`,

  'crossfade': `import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  final composition = VideoComposition(
    fps: 30,
    durationInFrames: 120,
    width: 1920,
    height: 1080,
    child: LayerStack(
      children: [
        // First scene (frames 0-60)
        Layer(
          id: 'scene1',
          startFrame: 0,
          endFrame: 60,
          fadeOutFrames: 15, // Crossfade duration
          child: Container(
            color: Colors.blue,
            child: Center(
              child: Text(
                'Scene 1',
                style: TextStyle(
                  fontSize: 64,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // Second scene (frames 45-120) - overlaps for crossfade
        Layer(
          id: 'scene2',
          startFrame: 45,
          endFrame: 120,
          fadeInFrames: 15, // Crossfade duration
          child: Container(
            color: Colors.purple,
            child: Center(
              child: Text(
                'Scene 2',
                style: TextStyle(
                  fontSize: 64,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}`,

  'template': `import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  // Use a pre-built template
  final template = TheNeonGateTemplate(
    data: IntroData(
      title: 'Welcome to 2024',
      subtitle: 'Your Year in Review',
      theme: NeonTheme(),
    ),
  );

  // Convert template to a scene
  final scene = template.toScene(
    fps: 30,
    width: 1920,
    height: 1080,
  );

  // Render
  final renderService = RenderService();
  final output = await renderService.execute(
    config: scene.config,
    onFrameUpdate: (frame) {
      final progress = (frame / scene.durationInFrames * 100).toStringAsFixed(1);
      print('Progress: $progress%');
    },
  );

  print('Video saved: $output');
}`,

  'audio-sync': `import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  // Audio-synchronized animation
  final composition = VideoComposition(
    fps: 30,
    durationInFrames: 300, // 10 seconds
    width: 1920,
    height: 1080,
    audioTracks: [
      AudioTrack(
        source: AudioSource.file('assets/music.mp3'),
        volume: 1.0,
        fadeIn: Duration(milliseconds: 500),
        fadeOut: Duration(milliseconds: 500),
      ),
    ],
    child: SyncAnchor(
      bpm: 120, // Music tempo
      child: LayerStack(
        children: [
          Layer.background(
            child: Container(color: Colors.black),
          ),

          // Pulsing circle on every beat
          Layer(
            id: 'pulse',
            startFrame: 0,
            endFrame: 300,
            child: TimeConsumer(
              builder: (context, frame, progress) {
                // Get beat info from SyncAnchor
                final syncData = SyncAnchor.of(context);
                final beatStrength = syncData.getBeatStrength(frame);

                return Center(
                  child: Container(
                    width: 100 + (beatStrength * 50),
                    height: 100 + (beatStrength * 50),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(beatStrength),
                          blurRadius: 30 * beatStrength,
                          spreadRadius: 10 * beatStrength,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}`,
};

// Store Monaco editor instance globally
window.monacoEditor = null;

// Initialize Monaco Editor
function initMonacoEditor() {
  require.config({
    paths: {
      vs: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.44.0/min/vs'
    }
  });

  require(['vs/editor/editor.main'], function() {
    // Register Dart language (basic support)
    monaco.languages.register({ id: 'dart' });

    // Set Dart language configuration
    monaco.languages.setMonarchTokensProvider('dart', {
      tokenizer: {
        root: [
          [/\b(class|void|final|const|var|import|package|return|if|else|for|while|async|await)\b/, 'keyword'],
          [/\b(String|int|double|bool|List|Map|Widget|BuildContext|Color|TextStyle)\b/, 'type'],
          [/\b(VideoComposition|LayerStack|Layer|TimeConsumer|RenderService|AudioTrack|SyncAnchor)\b/, 'type.identifier'],
          [/\/\/.*$/, 'comment'],
          [/"[^"]*"/, 'string'],
          [/'[^']*'/, 'string'],
          [/\d+/, 'number'],
        ]
      }
    });

    // Create editor
    const editor = monaco.editor.create(document.getElementById('code-editor'), {
      value: codeExamples['hello-fluvie'],
      language: 'dart',
      theme: 'vs-dark',
      fontSize: 14,
      fontFamily: "'Fira Code', 'JetBrains Mono', 'Consolas', monospace",
      minimap: { enabled: false },
      scrollBeyondLastLine: false,
      lineNumbers: 'on',
      roundedSelection: true,
      automaticLayout: true,
      readOnly: false,
      wordWrap: 'on',
      contextmenu: true,
      formatOnPaste: true,
      formatOnType: true,
    });

    // Store editor instance globally
    window.monacoEditor = editor;

    // Example selector functionality
    const exampleSelector = document.getElementById('example-selector');
    if (exampleSelector) {
      exampleSelector.addEventListener('change', (e) => {
        const selectedExample = e.target.value;
        if (codeExamples[selectedExample]) {
          editor.setValue(codeExamples[selectedExample]);
          updatePreview(selectedExample);
        }
      });
    }

    // Update preview when code changes (debounced)
    let updateTimeout;
    editor.onDidChangeModelContent(() => {
      clearTimeout(updateTimeout);
      updateTimeout = setTimeout(() => {
        analyzeCode(editor.getValue());
      }, 500);
    });

    // Initial preview
    updatePreview('hello-fluvie');
  });
}

// Update preview based on selected example
function updatePreview(exampleKey) {
  const previewOutput = document.getElementById('preview-output');
  if (!previewOutput) return;

  const previews = {
    'hello-fluvie': `
      <div class="preview-info">
        <h4>Composition Structure:</h4>
        <ul>
          <li><strong>Resolution:</strong> 1920x1080 (Full HD)</li>
          <li><strong>FPS:</strong> 30 frames per second</li>
          <li><strong>Duration:</strong> 90 frames (3 seconds)</li>
          <li><strong>Layers:</strong> 2 (background + text)</li>
        </ul>
        <h4>Animation:</h4>
        <ul>
          <li>Gradient background with fade-in (15 frames)</li>
          <li>Text scales from 50% to 100% size</li>
          <li>Text fades in/out at start/end</li>
        </ul>
      </div>
    `,
    'crossfade': `
      <div class="preview-info">
        <h4>Composition Structure:</h4>
        <ul>
          <li><strong>Duration:</strong> 120 frames (4 seconds)</li>
          <li><strong>Transition:</strong> 15-frame crossfade</li>
          <li><strong>Scenes:</strong> 2 with color transitions</li>
        </ul>
        <h4>Timeline:</h4>
        <ul>
          <li>Scene 1: Frames 0-60 (blue background)</li>
          <li>Crossfade: Frames 45-60 (overlap)</li>
          <li>Scene 2: Frames 45-120 (purple background)</li>
        </ul>
      </div>
    `,
    'template': `
      <div class="preview-info">
        <h4>Template:</h4>
        <ul>
          <li><strong>Name:</strong> The Neon Gate</li>
          <li><strong>Category:</strong> Intro</li>
          <li><strong>Style:</strong> Cyberpunk neon theme</li>
        </ul>
        <h4>Customization:</h4>
        <ul>
          <li>Custom title and subtitle text</li>
          <li>Neon color theme applied</li>
          <li>Pre-configured animations included</li>
          <li>Ready to render immediately</li>
        </ul>
      </div>
    `,
    'audio-sync': `
      <div class="preview-info">
        <h4>Audio Integration:</h4>
        <ul>
          <li><strong>Track:</strong> music.mp3</li>
          <li><strong>BPM:</strong> 120 (detected or specified)</li>
          <li><strong>Sync:</strong> Beat-reactive animations</li>
        </ul>
        <h4>Effects:</h4>
        <ul>
          <li>Circle pulses on every beat</li>
          <li>Size scales with beat strength</li>
          <li>Glow intensity synced to music</li>
          <li>Audio fade in/out for smooth start/end</li>
        </ul>
      </div>
    `,
  };

  previewOutput.innerHTML = previews[exampleKey] || `
    <div class="preview-placeholder">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
        <circle cx="8.5" cy="8.5" r="1.5"></circle>
        <polyline points="21 15 16 10 5 21"></polyline>
      </svg>
      <p>Full rendering requires Flutter SDK + FFmpeg</p>
    </div>
  `;
}

// Analyze code and show structure info
function analyzeCode(code) {
  const previewOutput = document.getElementById('preview-output');
  if (!previewOutput) return;

  // Simple code analysis
  const hasVideoComposition = code.includes('VideoComposition');
  const hasLayerStack = code.includes('LayerStack');
  const hasAudio = code.includes('AudioTrack') || code.includes('audioTracks');
  const hasTemplate = code.includes('Template');
  const hasTimeConsumer = code.includes('TimeConsumer');

  // Extract FPS if present
  const fpsMatch = code.match(/fps:\s*(\d+)/);
  const fps = fpsMatch ? fpsMatch[1] : 'Not specified';

  // Extract duration if present
  const durationMatch = code.match(/durationInFrames:\s*(\d+)/);
  const duration = durationMatch ? durationMatch[1] : 'Not specified';

  // Extract resolution
  const widthMatch = code.match(/width:\s*(\d+)/);
  const heightMatch = code.match(/height:\s*(\d+)/);
  const resolution = widthMatch && heightMatch
    ? `${widthMatch[1]}x${heightMatch[1]}`
    : 'Not specified';

  // Count layers
  const layerCount = (code.match(/Layer\(/g) || []).length +
                     (code.match(/Layer\.background\(/g) || []).length;

  let analysis = '<div class="preview-info"><h4>Code Analysis:</h4><ul>';

  if (hasVideoComposition) {
    analysis += `<li><strong>Type:</strong> Video Composition</li>`;
    if (resolution !== 'Not specified') {
      analysis += `<li><strong>Resolution:</strong> ${resolution}</li>`;
    }
    if (fps !== 'Not specified') {
      analysis += `<li><strong>FPS:</strong> ${fps}</li>`;
    }
    if (duration !== 'Not specified') {
      const seconds = (parseInt(duration) / parseInt(fps || 30)).toFixed(2);
      analysis += `<li><strong>Duration:</strong> ${duration} frames (~${seconds}s)</li>`;
    }
  }

  if (hasLayerStack) {
    analysis += `<li><strong>Layers:</strong> ${layerCount}</li>`;
  }

  if (hasTimeConsumer) {
    analysis += `<li><strong>Animation:</strong> Frame-based animation detected</li>`;
  }

  if (hasAudio) {
    analysis += `<li><strong>Audio:</strong> Audio tracks configured</li>`;
  }

  if (hasTemplate) {
    analysis += `<li><strong>Template:</strong> Using pre-built template</li>`;
  }

  analysis += '</ul></div>';

  // Add note about rendering
  analysis += `
    <div class="preview-note" style="margin-top: 1rem; padding: 1rem; background: rgba(255, 193, 7, 0.1); border-left: 3px solid #FFC107; border-radius: 4px;">
      <p style="margin: 0; font-size: 0.875rem; color: #FFC107;">
        <strong>⚠️ Note:</strong> Full video rendering requires Flutter SDK and FFmpeg installed locally.
        This preview shows the code structure only.
      </p>
    </div>
  `;

  previewOutput.innerHTML = analysis;
}

// Initialize editor when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initMonacoEditor);
} else {
  initMonacoEditor();
}
