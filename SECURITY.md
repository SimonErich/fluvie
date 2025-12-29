# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Fluvie, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email the maintainer directly at the email listed in the pubspec.yaml
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- Acknowledgment within 48 hours
- Status update within 7 days
- Fix timeline depends on severity

### Scope

Security issues we care about:

- Code execution vulnerabilities
- Path traversal in file operations
- Injection vulnerabilities in FFmpeg commands
- Memory safety issues
- Dependency vulnerabilities

### Out of Scope

- FFmpeg's own security issues (report to FFmpeg project)
- Denial of service through large files (expected behavior)
- Issues requiring physical device access

## Security Considerations

### FFmpeg Command Injection

Fluvie constructs FFmpeg commands internally. User-provided paths and filenames are used in these commands. The library:

- Does not shell-escape user input (FFmpeg is called directly via Process.start)
- Validates file paths where possible
- Uses temporary directories for intermediate files

### File System Access

Fluvie reads and writes files during rendering:

- Input: Images, videos, audio files
- Output: Rendered video files
- Temporary: Frame data during encoding

Ensure your application validates user-provided file paths before passing them to Fluvie.

### Web Platform (ffmpeg.wasm)

On web, FFmpeg runs in a sandboxed WebAssembly environment with limited file system access through a virtual file system.
