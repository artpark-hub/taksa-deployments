# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **deployment configuration repository** for the Taksa manufacturing platform. It contains Docker Compose and Kubernetes manifests for orchestrating the Taksa service stack. The primary working deployment is `platform/docker-compose/`.

## Common Commands

All deployment commands are run from `platform/docker-compose/`:

```bash
make init    # Create data directories + generate self-signed SSL certs
make up      # Start all services (detached)
make down    # Stop containers and remove volumes
make logs    # Tail container logs
make clean   # Full teardown: containers, data dirs, certs, env file
```

The underlying orchestration script is `taksa-stack-management.sh`, which composes Docker Compose files based on feature flags in `taksa.env`:
- `FEATURE_BASIC=true` — core services (required)
- `FEATURE_LOCAL=true` — optional local overrides

### SSL Certificate Generation

```bash
./scripts/generate-ssl-certs.sh
# Default domain: localcontroller.taksa.org
# Outputs: server.key, server.crt, server.pem under config/haproxy/certs/
```

### NATS Connectivity Tests

```bash
# Bash version
./tests/test-nats.sh

# Go version
cd tests && go run main.go
```

## Architecture Overview

The stack is a **Docker Compose-based microservices deployment** with these layers:

### API Gateway
- **HAProxy** handles HTTPS termination (port 443), ACL-based routing, and stats dashboard (port 8404).

### Identity & Access Control (Ory Stack)
- **Kratos** (port 4433/4434): Self-service identity management — login, registration, account recovery. Backed by PostgreSQL.
- **Oathkeeper** (port 4456/4457): Decision API + reverse proxy enforcing access rules defined in `config/ory-stack/oathkeeper/access-rules.yml`. Mutates requests by injecting JWT ID tokens for downstream services.

### Application Services
- **Taksa User Management** (port 8083): Custom backend handling master-user registration, sub-user management, and JWT token exchange. Sits behind Oathkeeper.
- **Taksa Device Management** (HTTP :8000, gRPC :9000): Device registration, telemetry ingestion, and async action distribution. Sits behind Oathkeeper.
- **Taksa App Traceability** (HTTP :8000, gRPC :9000): MES traceability service. Reads/writes manufacturing records to TimescaleDB. Depends on `taksa-tsdb`.
- **Taksa NATS Data Collector** (HTTP :8000, gRPC :9000): Subscribes to NATS JetStream (`NATS_SUBJECT`, default `uns.v1.>`) and persists UNS messages to TimescaleDB. Depends on `taksa-tsdb` (healthy) and `taksa-nats`. Configured via `NATS_SUBJECT`, `NATS_QUEUE_GROUP`, `NATS_STREAM`, `NATS_DLQ` env vars.
- **Taksa UI** (port 3000): React/Node.js frontend.
- **Mailslurper**: SMTP testing server for email verification flows in development.

### Data Layer
- **PostgreSQL**: Stores Kratos identity/session data.
- **TimescaleDB**: Stores manufacturing time-series telemetry. Schema defined in `config/database/schemas/01-base-schema.sql`.
  - Key hypertable: `module_telemetry`
  - Hierarchy: Enterprises → Sites → Areas → Work Centers → Work Units → Control Modules

### Messaging
- **NATS/JetStream** (port 4222): Persistent message broker. Two accounts — `$SYS` (monitoring) and `TAKSA` (application). Config in `config/nats/nats-server.conf`.

### Monitoring
- **Grafana** (port 3300, proxied at `/grafana`): Dashboards backed by TimescaleDB datasource.

## Configuration

Copy `taksa.env.example` to `taksa.env` before running `make init`. Key variables:
- `DOMAIN` — base domain for SSL and Kratos cookies
- `KRATOS_DSN` / `TIMESCALE_DSN` — database connection strings
- `NATS_*` — server ports and credentials
- `SMTP_*` — mail server for recovery flows

Data is persisted under `/datadrive/taksa/data/` (created by `make init`).

## Key File Locations

| Purpose | Path |
|---|---|
| Docker Compose entry | `platform/docker-compose/docker-compose.taksa-base.yml` |
| Oathkeeper access rules | `platform/docker-compose/config/ory-stack/oathkeeper/access-rules.yml` |
| Kratos identity schema | `platform/docker-compose/config/ory-stack/kratos/identity.schema.json` |
| Database schema (SQL) | `platform/docker-compose/config/database/schemas/01-base-schema.sql` |
| HAProxy config | `platform/docker-compose/config/haproxy/haproxy.cfg` |
| NATS config | `platform/docker-compose/config/nats/nats-server.conf` |
| Environment template | `platform/docker-compose/taksa.env.example` |
