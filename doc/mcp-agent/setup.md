# MCP Server Setup Guide

Complete guide for self-hosting the Fluvie MCP server.

---

## Prerequisites

- Docker and Docker Compose (recommended), OR
- Dart SDK 3.0+ for manual installation
- Port 8080 available (or configure alternate)

---

## Docker Installation (Recommended)

### Step 1: Clone Repository

```bash
git clone https://github.com/simonerich/fluvie.git
cd fluvie/mcp-server
```

### Step 2: Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```bash
# Server Configuration
PORT=8080
HOST=0.0.0.0

# Documentation path (relative to mcp-server directory)
DOCS_PATH=../doc

# Logging: debug, info, warning, error
LOG_LEVEL=info
```

### Step 3: Build and Run

```bash
# Development mode (rebuilds on changes)
docker-compose up

# Production mode (background)
docker-compose up -d

# View logs
docker-compose logs -f fluvie-mcp
```

### Step 4: Verify

```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "indexes": {
    "docs": { "status": "ready", "count": 87 },
    "templates": { "status": "ready", "count": 30 }
  }
}
```

---

## Production Deployment with HTTPS

For production with automatic HTTPS certificates:

### Step 1: Configure Domain

Point your domain (e.g., `mcp.fluvie.dev`) to your server's IP.

### Step 2: Set Environment

```bash
# .env
ACME_EMAIL=your-email@example.com
```

### Step 3: Start with Traefik

```bash
docker-compose --profile with-proxy up -d
```

This starts:
- Fluvie MCP server
- Traefik reverse proxy with Let's Encrypt

Your server is now available at `https://your-domain.com/mcp`

---

## Manual Installation (Without Docker)

### Step 1: Install Dart

```bash
# macOS
brew install dart

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install dart

# Or use the official installer
# https://dart.dev/get-dart
```

### Step 2: Clone and Setup

```bash
git clone https://github.com/simonerich/fluvie.git
cd fluvie/mcp-server
dart pub get
```

### Step 3: Configure

Create `.env` or set environment variables:

```bash
export PORT=8080
export HOST=0.0.0.0
export DOCS_PATH=../doc
export LOG_LEVEL=info
```

### Step 4: Run

```bash
# Development
dart run bin/server.dart

# Production (compiled)
dart compile exe bin/server.dart -o bin/server
./bin/server
```

---

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 8080 | Server port |
| `HOST` | 0.0.0.0 | Bind address |
| `DOCS_PATH` | ./data/docs | Path to documentation |
| `LOG_LEVEL` | info | Logging level |
| `ACME_EMAIL` | - | Email for Let's Encrypt |

---

## Updating Documentation

The server indexes documentation at startup. To update:

### Docker

```bash
# Restart to re-index
docker-compose restart fluvie-mcp
```

### Manual

```bash
# Just restart the server
./bin/server
```

---

## Monitoring

### Health Check

```bash
curl http://localhost:8080/health
```

### Docker Logs

```bash
docker-compose logs -f fluvie-mcp
```

### Container Status

```bash
docker-compose ps
```

---

## Troubleshooting

### Server Won't Start

1. Check port availability:
   ```bash
   lsof -i :8080
   ```

2. Check Docker logs:
   ```bash
   docker-compose logs fluvie-mcp
   ```

3. Verify documentation path exists and is readable

### Search Returns No Results

1. Check document count in `/health` response
2. Verify `DOCS_PATH` points to correct location
3. Check logs for indexing errors

### HTTPS Not Working

1. Verify domain DNS is configured
2. Check Traefik logs:
   ```bash
   docker-compose logs traefik
   ```
3. Ensure ports 80 and 443 are open

### Connection Refused

1. Check `HOST` is set to `0.0.0.0` (not `localhost`)
2. Verify firewall allows port 8080
3. Check container is running:
   ```bash
   docker ps
   ```

---

## Performance Tuning

### For High Traffic

```yaml
# docker-compose.yml
services:
  fluvie-mcp:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
```

### Multiple Instances

Use a load balancer with multiple server instances:

```yaml
services:
  fluvie-mcp:
    deploy:
      replicas: 3
```

---

## Security Considerations

1. **Run as non-root**: The Dockerfile creates a `fluvie` user
2. **Read-only docs**: Mount documentation as read-only (`:ro`)
3. **HTTPS**: Use Traefik or your own reverse proxy for TLS
4. **Rate limiting**: Configure at reverse proxy level

---

## Next Steps

- [IDE Integration](ide-integration.md) - Configure your IDE
- [MCP Agent Overview](README.md) - Using the MCP tools
