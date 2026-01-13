<center>
   <img src="./.github/assets/logo.png" width="40%" style="margin-bottom:1rem" />

   # Hytale Docker

   A Docker containerization setup for running a Hytale game server. This project provides a complete Docker Compose configuration with an automated build process to download and run the Hytale server.
</center>

## Overview

This project containerizes the Hytale server using Docker, making it easy to deploy and manage the server with consistent configuration. It includes:

- Automated Hytale server download and installation
- Docker Compose configuration for easy orchestration
- Configurable server options through environment variables
- Volume mounting for persistent data storage
- Automated backup functionality

### Pre-built Image

A pre-built Docker image is available on GitHub Container Registry:

- **Image**: `ghcr.io/machinastudios/hytale-docker`
- **Usage**: You can use this image directly without building it yourself

## Prerequisites

- Docker Engine (version 20.10 or later)
- Docker Compose (version 1.29 or later)

## Quick Start

Create a `docker-compose.yml` file:

```yaml
services:
    hytale:
        image: ghcr.io/machinastudios/hytale-docker
        ports:
            - "5520:5520/udp"
        volumes:
            - ./backups:/hytale/backups
            - ./mods:/hytale/mods
            - ./logs:/hytale/logs
            - ./universe:/hytale/universe
        environment:
            - SERVER_ACCEPT_EARLY_PLUGINS=true
            - SERVER_BIND=0.0.0.0:5520
            - SERVER_BACKUP_DIR=/hytale/backups
            - SERVER_BACKUP_INTERVAL=10
```

Then start the server:

```bash
docker-compose up -d
```

For detailed documentation, see:
- 🇺🇸 [English (EN)](./docs/en/Getting%20Started.md)
- 🇧🇷 [Português (PT-BR)](./docs/pt-BR/Iniciando.md)

## Notes

- The Hytale server requires Java 22 (provided by the OpenJDK base image)
- The downloader URL is: `https://downloader.hytale.com/hytale-downloader.zip`
- Server files are stored in `/hytale` inside the container
- The entrypoint script handles all server configuration dynamically
- All environment variables are optional; the server will use defaults if not set

## License

This project is a Docker setup for the Hytale server. Please refer to Hytale's official terms of service and licensing for server usage.

## Support

For issues related to:
- **Docker setup**: Check this repository's issues
- **Hytale server**: Refer to official Hytale documentation and support channels
- **Server configuration**: Review the [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual) for available options