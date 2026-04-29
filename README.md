# Hermes Agent Helm Chart

A clean, opinionated Helm chart for deploying [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Kubernetes.

**Chart version:** 0.1.0  
**App version:** 0.11.0  
**Helm:** 4.x (apiVersion v2)

## What This Chart Deploys

| Resource | Always | Conditional |
|----------|--------|-------------|
| Gateway | ✓ | |
| Dashboard | | `dashboard.enabled` |
| Service | ✓ | |
| ServiceAccount | ✓ | `serviceAccount.create` |
| ConfigMap (env) | ✓ | |
| ConfigMap (config) | | `hermes.config` or `hermes.soul` |
| Secret | | `secrets` map has entries |
| PersistentVolumeClaim | | `persistence.enabled` |
| Ingress | | `ingress.enabled` |
| HTTPRoute | | `httpRoute.enabled` |
| Init container (gh auth) | | `github.enabled` |

## Quick Start

```bash
# Add your values
cp examples/telegram-openrouter.yaml my-values.yaml
# Edit secrets and configuration
vim my-values.yaml

# Install
helm install hermes ./chart -f my-values.yaml

# Upgrade after changes
helm upgrade hermes ./chart -f my-values.yaml
```

## Prerequisites

- Kubernetes 1.27+
- Helm 4.x
- A container image built from the [official Dockerfile](https://github.com/NousResearch/hermes-agent/blob/main/Dockerfile), or the pre-built `ghcr.io/nousresearch/hermes-agent` image
- At least one LLM provider API key (OpenRouter, Anthropic, OpenAI, etc.)

## Architecture

```
┌──────────────────────────────────────────────────────┐
│ Pod                                                  │
│                                                      │
│  ┌──────────────┐    ┌────────────────────────────┐  │
│  │ init: gh-auth│───▶│ hermes (gateway run)       │  │
│  │ (optional)   │    │                            │  │
│  └──────────────┘    │  ┌──────────────────────┐  │  │
│                      │  │ Telegram Bot         │  │  │
│  ┌──────────────┐    │  │ Discord Bot          │  │  │
│  │ dashboard    │    │  │ API Server (:8642)   │  │  │
│  │ (optional)   │    │  └──────────────────────┘  │  │
│  └──────────────┘    └────────────┬───────────────┘  │
│                                   │                  │
│                      ┌────────────▼───────────────┐  │
│                      │ /opt/data (PVC)            │  │
│                      │  sessions/ skills/ memory/ │  │
│                      │  config.yaml .env logs/    │  │
│                      └────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
                          │
              ┌───────────▼────────────┐
              │ Service (ClusterIP)    │
              │ :8642 → API Server     │
              └───────────┬────────────┘
                          │
              ┌───────────▼────────────┐
              │ Ingress / HTTPRoute    │
              │ (optional)             │
              └────────────────────────┘
```

## Configuration

### Values Reference

#### Image

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.repository` | string | `ghcr.io/nousresearch/hermes-agent` | Container image |
| `image.tag` | string | `""` (appVersion) | Image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Pull policy |
| `imagePullSecrets` | list | `[]` | Registry pull secrets |

#### Hermes

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `hermes.resources` | map | `{}` | CPU/memory requests and limits for the gateway container |
| `hermes.home` | string | `/opt/data` | HERMES_HOME path |
| `hermes.config` | string | `null` | Contents of `config.yaml` (mounted via ConfigMap) |
| `hermes.soul` | string | `null` | Contents of `SOUL.md` persona file |

#### Dashboard

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `dashboard.enabled` | bool | `false` | Enable dashboard sidecar |
| `dashboard.port` | int | `9119` | Port |
| `dashboard.resources` | map | `{}` | CPU/memory requests and limits for the dashboard container |

#### Environment & Secrets

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `env` | map | `{HERMES_HUMAN_DELAY_MODE: "off"}` | Plain-text env vars |
| `secrets` | map | `{}` | Sensitive env vars (stored in a K8s Secret) |
| `existingSecret` | string | `""` | Name of a pre-existing Secret to load |

#### Gateway / Platforms

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `gateway.telegram.enabled` | bool | `false` | Enable Telegram bot |
| `gateway.telegram.homeChannel` | string | `""` | Default Telegram chat |
| `gateway.telegram.allowedUsers` | string | `""` | Comma-separated Telegram user IDs |
| `gateway.discord.enabled` | bool | `false` | Enable Discord bot |
| `gateway.discord.homeChannel` | string | `""` | Default Discord channel |
| `gateway.discord.allowedUsers` | string | `""` | Comma-separated Discord user IDs |
| `gateway.allowAllUsers` | bool | `false` | Allow messages from any user |

#### API Server

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `apiServer.enabled` | bool | `true` | Enable the OpenAI-compatible API server |
| `apiServer.host` | string | `0.0.0.0` | Bind address |
| `apiServer.port` | int | `8642` | Port |
| `apiServer.modelName` | string | `hermes-agent` | Model name in API responses |
| `apiServer.corsOrigins` | string | `""` | CORS allowed origins |

#### GitHub CLI

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `github.enabled` | bool | `false` | Run `gh auth login` in an init container |

**NOTE:** Requires `GITHUB_TOKEN` in `secrets` or `existingSecret`. Also requires a custom container that includes `gh`. A [Dockerfile](Dockerfile) is provided to build one.

#### Persistence

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `persistence.enabled` | bool | `true` | Create a PVC for HERMES_HOME |
| `persistence.storageClass` | string | `""` | Storage class (empty = cluster default) |
| `persistence.accessMode` | string | `ReadWriteOnce` | PVC access mode |
| `persistence.size` | string | `10Gi` | Volume size |
| `persistence.existingClaim` | string | `""` | Use a pre-existing PVC |

#### Networking

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `service.type` | string | `ClusterIP` | Service type |
| `service.port` | int | `8642` | Service port |
| `ingress.enabled` | bool | `false` | Create an Ingress resource |
| `ingress.className` | string | `""` | Ingress class |
| `httpRoute.enabled` | bool | `false` | Create an HTTPRoute (Gateway API) |
| `httpRoute.parentGateway` | string | `""` | Gateway resource name (required if enabled) |

#### Pod Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `nodeSelector` | map | `{}` | Node selection constraints |
| `tolerations` | list | `[]` | Pod tolerations |
| `affinity` | map | `{}` | Affinity rules |
| `podAnnotations` | map | `{}` | Extra pod annotations |
| `podLabels` | map | `{}` | Extra pod labels |
| `podSecurityContext` | map | `{}` | Pod-level security context |
| `securityContext` | map | `{}` | Container-level security context |
| `extraVolumes` | list | `[]` | Additional volumes |
| `extraVolumeMounts` | list | `[]` | Additional volume mounts |
| `extraInitContainers` | list | `[]` | Additional init containers |

#### Probes

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `livenessProbe.enabled` | bool | `false` | Enable liveness probe |
| `readinessProbe.enabled` | bool | `false` | Enable readiness probe |

Both probe to `GET /health` on the API server port when enabled.

## Examples

### Telegram + OpenRouter (most common)

```bash
helm install hermes ./chart -f examples/telegram-openrouter.yaml
```

See [`examples/telegram-openrouter.yaml`](examples/telegram-openrouter.yaml) — a complete setup with Telegram bot, OpenRouter as LLM provider, GitHub CLI integration, and persistence.

### Minimal API-only

```bash
helm install hermes ./chart -f examples/minimal-api.yaml
```

See [`examples/minimal-api.yaml`](examples/minimal-api.yaml) — just the API server with no messaging platforms.

### External Secrets (Sealed Secrets / Vault / ESO)

```bash
# Create your Secret externally first, then:
helm install hermes ./chart -f examples/external-secrets.yaml
```

See [`examples/external-secrets.yaml`](examples/external-secrets.yaml) — references a pre-existing Secret instead of managing credentials in Helm values.

## Secret Management

Three approaches, from simplest to most secure:

### 1. Inline in values (development)

```yaml
secrets:
  OPENROUTER_API_KEY: "sk-or-v1-..."
  TELEGRAM_BOT_TOKEN: "123456:ABC..."
```

Simple but secrets end up in Helm release history. Fine for dev, not for production.

### 2. `--set` flags (CI/CD)

```bash
helm install hermes ./chart \
  --set secrets.OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  --set secrets.TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
```

Keeps secrets out of files. Combine with CI/CD secret variables.

### 3. External Secret management (production)

Use [Sealed Secrets](https://sealed-secrets.netlify.app/), [External Secrets Operator](https://external-secrets.io/), or [Vault](https://www.vaultproject.io/) to create the Secret, then reference it:

```yaml
existingSecret: "hermes-credentials"
secrets: {}
```

## How It Works

### Entrypoint

The official Hermes Docker image uses an entrypoint (`docker/entrypoint.sh`) that:

1. Drops root privileges via `gosu` (configurable UID/GID via `HERMES_UID`/`HERMES_GID`)
2. Creates the directory structure under HERMES_HOME
3. Seeds `config.yaml`, `.env`, and `SOUL.md` from bundled defaults if they don't exist
4. Syncs bundled skills
5. Execs `hermes <args>`

The chart passes `gateway run` as args to this entrypoint.

### Config Layering

Configuration is resolved in this order:

1. **Image defaults** — baked into the Docker image
2. **ConfigMap (config)** — `hermes.config` is mounted as `/opt/data/config.yaml`
3. **ConfigMap (env)** — non-secret env vars from `env` + gateway/apiServer settings
4. **Secret** — sensitive env vars from `secrets` or `existingSecret`

Environment variables override `config.yaml` values for supported keys (see [Hermes docs](https://hermes-agent.nousresearch.com/docs/reference/environment-variables)).

### GitHub CLI Init Container

When `github.enabled: true`, an init container runs before the main Hermes container:

```bash
echo "$GITHUB_TOKEN" | gh auth login --with-token
```

This writes the auth config to `/opt/data/home/.config/gh/hosts.yml` on the persistent volume, so `gh` works in every Hermes shell session. The auth persists across pod restarts as long as the PVC is retained.

### Persistence

The PVC stores everything under HERMES_HOME:

```
/opt/data/
├── config.yaml      # Agent configuration
├── .env             # API keys (seeded from image defaults)
├── SOUL.md          # Persona file
├── sessions/        # Conversation transcripts
├── skills/          # Learned skills
├── memories/        # Persistent memory
├── cron/            # Scheduled job state
├── logs/            # Gateway and error logs
├── home/            # HOME for subprocesses (git, gh, ssh, npm)
│   └── .config/gh/  # GitHub CLI auth (from init container)
└── workspace/       # Working directory for tasks
```

**Without persistence**, all state is lost on pod restart. Always enable persistence for production.

## Upgrading

```bash
# Preview changes
helm diff upgrade hermes ./chart -f my-values.yaml

# Apply
helm upgrade hermes ./chart -f my-values.yaml
```

The Deployment uses `strategy: Recreate` to avoid two pods mounting the same RWO PVC simultaneously. Expect a brief downtime during upgrades.

Config and secret changes trigger a pod restart automatically (via checksum annotations).

## Troubleshooting

### Pod won't start

```bash
kubectl describe pod -l app.kubernetes.io/name=hermes-agent
kubectl logs -l app.kubernetes.io/name=hermes-agent --previous
```

### API server not reachable

```bash
# Port-forward and test
kubectl port-forward svc/hermes-hermes-agent 8642:8642
curl http://localhost:8642/v1/models
```

### GitHub CLI not working

```bash
# Check init container logs
kubectl logs deploy/hermes-hermes-agent -c gh-auth

# Verify auth inside the pod
kubectl exec deploy/hermes-hermes-agent -- gh auth status
```

### Check all environment variables

```bash
kubectl exec deploy/hermes-hermes-agent -- env | sort
```

## License

MIT
