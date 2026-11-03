# Kept on Railway: self-hosted home inventory with photos, QR labels, AI assistant and MCP

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/soGCEN)

[Kept](https://github.com/keptinventory/kept) (AGPL-3.0) is a home inventory: things, photos, receipts and warranties, locations and containers with printable QR labels, lending, reminders, an optional AI assistant (bring your own provider key) and an MCP server for agents. This template runs it the way upstream's `compose.yaml` does, with Postgres 18 + pgvector, and folds upstream's one-shot `bootstrap` and `migrate` services into the start of the Kept service. Ollama (local AI) is left out.

Image: `ghcr.io/onepush-dev/kept:1.14.3` = official `ghcr.io/keptinventory/kept:1.14.3` (pinned by digest, code unmodified) + a start wrapper:
1. waits for Postgres, creates the `kept` database if missing,
2. `kept bootstrap` (creates/updates the four least-privilege logins `kept_owner`, `kept_app`, `kept_auth`, `kept_system` and the pg_trgm / unaccent / vector extensions),
3. `kept migrate` (as `kept_owner`),
4. starts the server as uid 10001. The Postgres superuser password and the raw login passwords are removed from the server's environment first.

## Services
| Service | Image | Notes |
|---|---|---|
| Kept | `ghcr.io/onepush-dev/kept:1.14.3` | public HTTPS domain → 8080, health `/readyz`, restart always, volume `/data` (photos and files, generated keys in `/data/config/secrets.json`) |
| Postgres | `pgvector/pgvector:0.8.6-pg18-bookworm` (upstream's digest pin) | private only, volume `/var/lib/postgresql` |

## Variables (all generated or referenced, zero inputs)
| Service.Variable | Default |
|---|---|
| Kept.KEPT_PUBLIC_URL | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| Kept.KEPT_SETUP_CODE | `${{secret(6, "0123456789ABCDEFGHJKMNPQRSTVWXYZ")}}` (first-run setup code) |
| Kept.KEPT_DB_OWNER_PASSWORD / _APP_ / _AUTH_ / _SYSTEM_ | `${{secret(32, "abcdef0123456789")}}` each |
| Kept.PGHOST | `${{Postgres.RAILWAY_PRIVATE_DOMAIN}}` |
| Kept.PGPASSWORD | `${{Postgres.POSTGRES_PASSWORD}}` (superuser, only used by the bootstrap step) |
| Postgres.POSTGRES_PASSWORD | `${{secret(32, "abcdef0123456789")}}` |

Baked into the image: `KEPT_CONFIG_DIR=/data/config`, `KEPT_DATA_DIR=/data`, `KEPT_PORT=8080`, `KEPT_TRUSTED_PROXIES` = private/CGNAT ranges (Railway's edge), `KEPT_SOURCE_URL` = this repo, `TZ=UTC`.

## First run
Open the Railway domain. Kept shows its setup page: enter the setup code from the Kept service's `KEPT_SETUP_CODE` variable (also printed in the deploy logs as `KEPT SETUP CODE: XXX-XXX`), your email, a password and your name. That creates the instance admin; sign-up stays closed unless you open it (Admin, or `KEPT_SIGNUP_OPEN=true`).

## Notes
- Keep the recovery kit: `/data/config/secrets.json` holds `KEPT_SECRET_KEY` and `KEPT_AUTH_SECRET`; without them sealed values and backups cannot be read. Download it from Admin, or run `kept admin recovery-kit` in the service shell.
- AI: Settings → AI per location, with an OpenAI/Anthropic/Gemini/OpenRouter/Ollama-compatible key. Semantic search (pgvector) uses the provider's embeddings model.
- Optional: `KEPT_SMTP_URL` + `KEPT_SMTP_FROM` (invites, reminders, resets), OIDC / Google sign-in, S3 storage, restic backups (`KEPT_BACKUP_*`; `KEPT_OWNER_DATABASE_URL` is already set for the nightly dump), `KEPT_METRICS_TOKEN`. See upstream [compose.env.example](https://github.com/keptinventory/kept/blob/main/compose.env.example).
- Postgres major upgrades are a dump and restore, never a tag bump (upstream rule).

## License
Kept is AGPL-3.0; the deployed code is upstream v1.14.3 unmodified, and `KEPT_SOURCE_URL` points at this repo. This repo only holds Railway packaging.
