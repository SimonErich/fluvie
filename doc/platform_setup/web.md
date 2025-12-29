# Web Setup

> **Configure FFmpeg.wasm for browser-based video encoding**

Fluvie uses [ffmpeg.wasm](https://ffmpegwasm.netlify.app/) for web platform support. This runs FFmpeg entirely in the browser using WebAssembly.

## Table of Contents

- [Requirements](#requirements)
- [Server Configuration](#server-configuration)
- [Local Development](#local-development)
- [FFmpeg.wasm Versions](#ffmpegwasm-versions)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)

---

## Requirements

### CORS Headers

FFmpeg.wasm requires SharedArrayBuffer, which needs specific security headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### Server Configuration

#### Nginx

```nginx
location / {
    add_header Cross-Origin-Opener-Policy same-origin;
    add_header Cross-Origin-Embedder-Policy require-corp;
}
```

#### Apache

```apache
<IfModule mod_headers.c>
    Header set Cross-Origin-Opener-Policy "same-origin"
    Header set Cross-Origin-Embedder-Policy "require-corp"
</IfModule>
```

#### Express.js

```javascript
app.use((req, res, next) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  next();
});
```

#### Firebase Hosting

Add to `firebase.json`:

```json
{
  "hosting": {
    "headers": [
      {
        "source": "**/*",
        "headers": [
          {
            "key": "Cross-Origin-Opener-Policy",
            "value": "same-origin"
          },
          {
            "key": "Cross-Origin-Embedder-Policy",
            "value": "require-corp"
          }
        ]
      }
    ]
  }
}
```

#### Vercel

Add to `vercel.json`:

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Cross-Origin-Opener-Policy",
          "value": "same-origin"
        },
        {
          "key": "Cross-Origin-Embedder-Policy",
          "value": "require-corp"
        }
      ]
    }
  ]
}
```

#### Netlify

Add to `netlify.toml`:

```toml
[[headers]]
  for = "/*"
  [headers.values]
    Cross-Origin-Opener-Policy = "same-origin"
    Cross-Origin-Embedder-Policy = "require-corp"
```

## Local Development

### Flutter's Built-in Server

Flutter's `flutter run -d chrome` doesn't support custom headers. Options:

1. **Use a local server** - Run a simple server with headers:
   ```bash
   npx http-server build/web --cors -c-1 \
     --header "Cross-Origin-Opener-Policy: same-origin" \
     --header "Cross-Origin-Embedder-Policy: require-corp"
   ```

2. **Use the Fluvie dev server** (if available in example):
   ```bash
   cd example
   flutter build web
   # Run with headers enabled
   ```

## FFmpeg.wasm Versions

Fluvie uses ffmpeg.wasm loaded from CDN. The library handles loading automatically.

### Custom CDN Path

If you need to host ffmpeg.wasm yourself:

```dart
// This would require modifying WasmFFmpegProvider
// to accept a custom base URL (future feature)
```

## Limitations

### Browser Compatibility

FFmpeg.wasm requires:
- Chrome 89+
- Firefox 79+
- Safari 15.2+
- Edge 89+

### Performance

- WebAssembly is slower than native FFmpeg
- Large videos may cause memory issues
- Consider limiting resolution/duration for web

### File Size

FFmpeg.wasm adds ~25MB to your app (loaded on demand).

## Troubleshooting

### SharedArrayBuffer Not Available

Error: `SharedArrayBuffer is not defined`

This means CORS headers are not set. Check your server configuration.

### Out of Memory

WebAssembly has memory limits. For large videos:

1. Reduce resolution
2. Process in smaller chunks
3. Increase memory limit (if possible)

### Slow Performance

Tips for better web performance:

1. Use lower resolution (720p instead of 1080p)
2. Use shorter durations
3. Reduce frame rate (24fps instead of 60fps)
4. Consider preprocessing complex compositions

### CORS Errors with External Resources

If loading external images/videos, ensure they have proper CORS headers:

```html
<img crossorigin="anonymous" src="..." />
```

Or proxy them through your server.

---

## Related

- [Platform Overview](overview.md) - All platforms
- [FFmpeg Setup](../getting-started/ffmpeg-setup.md) - General FFmpeg guide
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Custom integrations
- [Performance Tips](../advanced/performance-tips.md) - Optimization for web
