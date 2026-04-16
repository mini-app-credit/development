# Mini Credit — Development Environment

## Quick Start

```bash
# 1. Create deployment config from example
cp -r deployment.example/ deployment/
# Edit deployment/deployment.env and deployment/sensitive.env

# 2. (Optional) mkcert + SSL files if you need HTTPS elsewhere
# brew install mkcert && make ssl-gen

# 3. (Optional) Add domains to /etc/hosts — make hosts-add

# 4. Start in dev mode (hot reload)
make dev-up

# 5. Push database schema
make db-push
```

After startup, use **localhost** URLs below. There is no reverse proxy in Compose.

## SSL Certificates

You can still generate local certificates with [mkcert](https://github.com/FiloSottile/mkcert) for your own tooling:

```bash
brew install mkcert
make ssl-gen
```

This creates:

- `deployment/ssl/cert.pem` — wildcard для `*.mini-credit.local`
- `deployment/ssl/key.pem` — приватный ключ
- `deployment/ssl/ca.pem` — CA

**Never commit certificates.** The `deployment/` directory and `*.pem` / `*.key` files are in `.gitignore`.

## /etc/hosts

```bash
make hosts-add
```

Only needed if you want `*.mini-credit.local` to resolve without editing `/etc/hosts` by hand.

## Commands

```bash
make help               # Show all commands

make ssl-gen            # SSL certificates (mkcert + sudo)
make hosts-add          # /etc/hosts (sudo)

make up                 # Build images, run full stack (prod-like)
make dev-up             # Dev: bind-mount app, frontend, templates
make dev-infra-up       # Infra only: postgres, redis, mailpit, templates
make down               # Stop
make restart            # Restart (optional SERVICES=a,b)
make destroy            # Stop + volumes

make logs               # Logs (optional SERVICES=mini-credit-api)
make status             # docker compose ps

make db-push            # Drizzle schema push
make db-gen             # Generate migration
make db-studio          # Drizzle Studio

make test-up            # Test postgres (5433) + redis (6380)
make test-down
make test-unit / test-integration / test-e2e

make validate           # Pre-flight
```

## Domains and ports

Direct port access (no Nginx in Docker):

- `http://localhost:4000` — frontend
- `http://localhost:3000` — API
- `http://localhost:3100` — templates (React Email)
- `http://localhost:8025` — Mailpit UI

Object storage is **AWS S3** (configure `S3_*` and `AWS_*` in `deployment/sensitive.env` and `vendor.env`). No MinIO in Compose.

## Stack (docker-compose)

Single `docker-compose.yml` defines:

- **Infra:** Postgres, Redis, Mailpit, postgres-init
- **Apps:** API, Worker, Frontend, Templates

`docker-compose.dev.yml` overrides API/Worker/Frontend/Templates with Node images, bind mounts, and dev commands (`make dev-up`).

NATS and a separate landing app are not part of this compose file.

## Environment files

Load order (later overrides earlier):

1. `vendor.env` — versioned defaults (ports, internal hostnames)
2. `deployment/deployment.env` — domains, project name (not in git if copied from example)
3. `deployment/sensitive.env` — secrets (not in git)
4. `derived.env` — optional computed values (versioned if present)

Setup: `cp -r deployment.example/ deployment/` then edit, then `make ssl-gen` if you need certs.

## Directory layout

```
development/
├── Makefile
├── README.md
├── docker-compose.yml       # Full stack
├── docker-compose.dev.yml   # Dev overrides
├── docker-compose.test.yml  # Test Postgres + Redis only
├── vendor.env
├── derived.env
├── deployment/              # local (gitignored when copied)
├── deployment.example/
└── provisioning/
    ├── postgres/
    └── ssl/generate.sh
```

## Troubleshooting

**Certificate errors:** `make ssl-gen` then `make down && make dev-up`. Run `mkcert -install` if the OS does not trust the CA.

**Hosts missing:** `grep mini-credit /etc/hosts` — run `make hosts-add` if needed.

**Validation fails:** `make validate` — often `cp -r deployment.example/ deployment/` and `make ssl-gen`.

**Frontend HMR:** configure `hmr` in `vite.config` for direct `localhost` (see frontend repo).
