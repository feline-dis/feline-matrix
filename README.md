# feline-matrix

A Dendrite Matrix homeserver deployed on Fly.io.

## Architecture

```
Internet (clients)           Internet (federation)
       |                            |
  port 443 (HTTPS)             port 8448 (TLS)
  Fly Proxy                    Fly Proxy
       |                            |
  +----|-----------------------------|----+
  |    |         Fly Machine         |    |
  |    |                             |    |
  |    +--- dendrite :8008 (client)  |    |
  |         dendrite :8448 (federation)   |
  |              |                        |
  +--------------|-----------+------------+
                 |           |
          Railway Postgres   Fly Volume
          (external DB)      /data (media, jetstream, search)
```

A single Fly Machine runs the Dendrite monolith. Fly's proxy terminates TLS on both ports. PostgreSQL is hosted externally on Railway. Media, JetStream, and search index data persist on a Fly volume.

## Project structure

```
.
├── config/
│   ├── dendrite.yaml        # Dendrite configuration
│   └── matrix_key.pem       # Signing key (generated, gitignored)
├── scripts/
│   ├── generate-keys.sh     # Generate matrix_key.pem via Docker
│   ├── create-account.sh    # Create user accounts on Fly
│   └── fly-entrypoint.sh    # Fly runtime: injects secrets, remaps paths
├── Dockerfile               # Fly build: dendrite image with config baked in
├── fly.toml                 # Fly app configuration (gitignored)
└── .env.example             # Environment variable template
```

### Key files

**`config/dendrite.yaml`** -- The Dendrite configuration file. For Fly, the entrypoint script patches it at boot to inject the database URI and remap data paths.

**`Dockerfile`** -- Builds on the official `dendrite-monolith` image. Copies in the config, signing key, and entrypoint script. Overrides the default entrypoint so secrets can be injected before Dendrite starts.

**`fly.toml`** -- Defines the Fly app. Exposes the client API on port 443 (HTTPS, health-checked against `/_matrix/client/versions`) and federation on port 8448 (TCP with TLS). Mounts a persistent volume at `/data`. Gitignored because it contains the app-specific name.

**`scripts/fly-entrypoint.sh`** -- Runs at container start on Fly. Replaces the `connection_string` in dendrite.yaml with the `DATABASE_URI` secret, remaps data paths to `/data/*`, creates data directories, then execs into the Dendrite binary.

**`scripts/create-account.sh`** -- Creates Matrix user accounts on the Fly deployment via SSH.

## Deploy to Fly.io

### Prerequisites

- [flyctl](https://fly.io/docs/flyctl/install/) installed and authenticated
- A PostgreSQL database (e.g., Railway) with the connection URI ready

### Steps

1. **Create the Fly app and volume:**

   ```sh
   fly apps create <app-name>
   fly volumes create dendrite_data --region <region> --size 1
   ```

2. **Update `fly.toml`:**

   Set the `app` field to your app name and `primary_region` to your chosen region.

3. **Generate the signing key:**

   ```sh
   bash scripts/generate-keys.sh
   ```

4. **Configure `dendrite.yaml`:**

   Edit `config/dendrite.yaml` and set `server_name` to your domain (e.g., `matrix.yourdomain.com`). If your server name differs from the hostname clients connect to, uncomment and set `well_known_server_name`.

5. **Set secrets:**

   ```sh
   fly secrets set DATABASE_URI="postgres://user:pass@host:port/dbname"
   ```

6. **Deploy:**

   ```sh
   fly deploy
   ```

7. **Set up DNS:**

   ```sh
   fly ips list
   ```

   Create A and AAAA records for your domain pointing to the IPs shown. Use **DNS-only mode** (not proxied) -- Cloudflare's proxy does not support port 8448.

8. **Create an admin account:**

   ```sh
   bash scripts/create-account.sh -username admin -admin
   ```

### Verification

- Check the machine is running: `fly status`
- Test the client API: `curl https://<app-name>.fly.dev/_matrix/client/versions`
- Test federation: https://federationtester.matrix.org

## Management

### Creating user accounts

```sh
bash scripts/create-account.sh -username alice

# Admin account
bash scripts/create-account.sh -username admin -admin
```

### Redeploying after config changes

Edit `config/dendrite.yaml` locally, then redeploy:

```sh
fly deploy
```

The config is baked into the Docker image at build time. The entrypoint script patches it with secrets at runtime.

### Checking logs

```sh
fly logs
```

### SSH into the machine

```sh
fly ssh console
```

### Secrets

Secrets are managed via `fly secrets` and injected by the entrypoint script at boot:

```sh
fly secrets set DATABASE_URI="postgres://..."
fly secrets list
```

Changing a secret triggers a redeployment automatically.
