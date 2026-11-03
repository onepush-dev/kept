# Kept on Railway: the official image (pinned by digest) plus a start wrapper that does what
# upstream's compose does with one-shot services: wait for Postgres, create the `kept` database,
# `kept bootstrap` (the four database logins + pg_trgm/unaccent/vector), `kept migrate`, then the
# server. Railway gives one volume per service, so generated keys live in /data/config.
FROM ghcr.io/keptinventory/kept:1.14.3@sha256:a503e00f4608f4485400515fc0687042e6976312ef2ee2ace2d613f0d280aa5b
LABEL org.opencontainers.image.source="https://github.com/onepush-dev/kept" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
USER root
COPY --chmod=755 railway/railway-start.sh /usr/local/bin/railway-start.sh
# Defaults baked into the image (Railway templates keep only secrets and references).
# KEPT_TRUSTED_PROXIES: Railway's edge reaches the container from private/CGNAT addresses;
# X-Forwarded-For from them is believed, so rate limits and audit logs see the real client.
# KEPT_SOURCE_URL: AGPL source offer points at this packaging repo (upstream code unmodified).
ENV KEPT_CONFIG_DIR=/data/config \
    KEPT_DATA_DIR=/data \
    KEPT_PORT=8080 \
    PORT=8080 \
    KEPT_TRUSTED_PROXIES=10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,fd00::/8 \
    KEPT_LOG_FORMAT=json \
    KEPT_SOURCE_URL=https://github.com/onepush-dev/kept \
    TZ=UTC
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
