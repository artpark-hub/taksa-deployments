# Taksa Platform Deployments

This directory contains the Docker Compose configurations for the Taksa platform services.

## Getting Started

A `Makefile` is provided to simplify the management of the Docker containers.

### 1. Initialization

Before running the services for the first time, you need to create the persistent data directories on your host system.

```bash
make init
```

*Note: This creates the `/datadrive/taksa/postgres` directory. Ensure you have the necessary permissions or run with `sudo` if required.*

### 2. Starting the Services

To start all services in detached mode:

```bash
make up
```

This will:
- Start the Postgres database.
- Run Kratos migrations.
- Start Kratos (Identity Server).
- Start Oathkeeper (Identity & Access Proxy).
- Start Mailslurper (SMTP testing server).

### 3. Stopping the Services

To stop and remove the containers:

```bash
make down
```

### 4. Viewing Logs

To follow the logs of all running services:

```bash
make logs
```

## Configuration

- **ORY Stack:** Configuration files are located in the `ory-stack/` directory.
- **Persistence:** Postgres data is persisted at `/datadrive/taksa/postgres`.
