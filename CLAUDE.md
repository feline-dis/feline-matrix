# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Self-hosted Matrix homeserver (Dendrite) on a Hetzner VPS for `ohana-matrix.xyz`, with Element Call (LiveKit) for voice/video. A Go reverse proxy sits in front of Dendrite to add invite-code-gated user registration. Everything runs via `docker-compose.yml`.

## Architecture

```
Internet
  |
  Caddy (:80, :443, :8448)
    |
    +-- /.well-known/matrix/client  -> static JSON (served by Caddy)
    +-- /.well-known/matrix/server  -> static JSON (served by Caddy)
    +-- /sfu/get*                   -> lk-jwt-service:8080 (JWT auth for LiveKit)
    +-- /sfu*                       -> livekit:7880 (WebSocket)
    +-- /*                          -> registration-proxy:8008
                                         +-- /register/*    -> embedded static UI
                                         +-- /api/register  -> invite-gated handler
                                         +-- /*             -> dendrite:8008
    |
    +-- :8448 /*                    -> dendrite:8008 (federation, TLS by Caddy)

  LiveKit direct host ports:
    7881/tcp  (ICE TCP fallback)
    50000-50200/udp (WebRTC media)
```

- **Caddy** terminates TLS for everything including federation on :8448.
- **Dendrite** listens on HTTP :8008 only (no HTTPS listener).
- **Registration proxy** (`registration/main.go`): Go binary using only stdlib. Serves the registration UI, validates invite codes, computes HMAC-SHA1 against Dendrite's admin registration API, and reverse-proxies all other traffic to Dendrite.
- **LiveKit** handles WebRTC media for Element Call voice/video.
- **lk-jwt-service** issues JWT tokens for LiveKit access, scoped to `ohana-matrix.xyz`.
- Static registration UI files (`registration/www/`) are embedded into the Go binary via `//go:embed`.

## Build and Development

### Build the Go proxy locally

```bash
cd registration && go build -o registration-proxy .
```

### Run the full stack locally

```bash
cp .env.example .env   # fill in values
docker compose up -d
```

### Build just the proxy image

```bash
docker build -t feline-matrix .
```

The Dockerfile is a two-stage build: compiles the Go proxy in `golang:1.25-alpine`, then copies it into a plain `alpine:latest` image.

### Deploy

On the VPS, pull latest and restart:

```bash
git pull && docker compose up -d --build
```

### Create accounts

```bash
docker compose exec dendrite /usr/bin/create-account -config /tmp/dendrite.yaml -username alice
docker compose exec dendrite /usr/bin/create-account -config /tmp/dendrite.yaml -username admin -admin
```

## Runtime Secrets

Managed via `.env` file (not committed). The dendrite entrypoint (`scripts/dendrite-entrypoint.sh`) injects `DATABASE_URI` and `REGISTRATION_SHARED_SECRET` into `config/dendrite.yaml` at container startup using `sed`.

- `DATABASE_URI` - PostgreSQL connection string (Railway)
- `REGISTRATION_SHARED_SECRET` - Dendrite admin registration secret
- `INVITE_CODE` - required invite code for the registration form
- `DENDRITE_URL` - URL the proxy uses to reach Dendrite (default: `http://dendrite:8008`)
- `LIVEKIT_KEY` - LiveKit API key
- `LIVEKIT_SECRET` - LiveKit API secret

## Key Files

- `registration/main.go` - the entire proxy server (single file, stdlib only)
- `config/dendrite.yaml` - Dendrite config template (placeholders replaced at runtime)
- `docker-compose.yml` - full stack: Caddy, Dendrite, registration proxy, LiveKit, lk-jwt-service
- `Caddyfile` - reverse proxy routing and TLS termination
- `livekit/livekit.yaml` - LiveKit server configuration
- `scripts/dendrite-entrypoint.sh` - container entrypoint; injects secrets, generates signing key, starts Dendrite
- `.env.example` - template for required environment variables

## Conventions

- The Go module (`registration/`) uses zero external dependencies -- stdlib only.
- No test suite exists yet.
- No linter or formatter is configured. Standard `gofmt` applies.
- The signing key (`matrix_key.pem`) is generated on first boot onto the persistent volume (`/data`), not baked into the image.

## Dendrite + Element Call Caveat

Dendrite is missing MSC4140/MSC4222 support, so call state may get stale if a client crashes mid-call. Core calling (audio, video, screen share) works fine once both parties join.
