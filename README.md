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

- **Image**: `ghcr.io/machinastudios/hytale`
- **Usage**: You can use this image directly without building it yourself

## Prerequisites

- Docker Engine (version 20.10 or later)
- Docker Compose (version 1.29 or later)

## Quick Start

Create a `docker-compose.yml` file:

```yaml
services:
    hytale:
        image: ghcr.io/machinastudios/hytale
        stdin_open: true
        tty: true
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
            - SERVER_MAX_VIEW_RADIUS=12
```

Then start the server and attach to the console:

```bash
# Using the run script (recommended)
./run.sh          # Linux/macOS
run.cmd           # Windows

# Or manually
docker-compose up -d
docker attach hytale
```

> **Tip**: Press `Ctrl+P`, `Ctrl+Q` to detach from the console without stopping the server.

For detailed documentation, see:
- 🇺🇸 [English (EN)](./docs/en/Getting%20Started.md)
- 🇧🇷 [Português (PT-BR)](./docs/pt-BR/Iniciando.md)

## Debugging with Java

The Hytale Docker setup supports remote Java debugging using JDWP (Java Debug Wire Protocol). This allows you to attach a debugger from your IDE to the running server.

### Enabling Debug Mode

To enable Java debugging, set the `JAVA_DEBUG` environment variable to `true` in your `docker-compose.yml`:

```yaml
services:
    hytale:
        image: ghcr.io/machinastudios/hytale
        ports:
            - "5520:5520/udp"
            - "5005:5005/tcp"  # JDWP debug port
        environment:
            - JAVA_DEBUG=true
```

The debug port `5005` is automatically exposed when debug mode is enabled. The server will start with JDWP agent configured to listen on `*:5005`.

### Connecting from Your IDE

#### Visual Studio Code

1. Create or update `.vscode/launch.json`:

```json
{
    "configurations": [
        {
            "name": "Attach to Hytale Server",
            "type": "java",
            "request": "attach",
            "hostName": "localhost",
            "port": 5005
        }
    ]
}
```

2. Start the server with debug enabled
3. Set breakpoints in your code
4. Press `F5` or use the Debug panel to attach to the server

#### IntelliJ IDEA / Android Studio

1. Go to **Run** → **Edit Configurations...**
2. Click **+** → **Remote JVM Debug**
3. Configure:
   - **Name**: `Hytale Server Debug`
   - **Host**: `localhost`
   - **Port**: `5005`
   - **Debugger mode**: `Attach to remote JVM`
4. Click **OK** and start debugging

#### Eclipse

1. Go to **Run** → **Debug Configurations...**
2. Right-click **Remote Java Application** → **New**
3. Configure:
   - **Name**: `Hytale Server Debug`
   - **Project**: Select your project
   - **Host**: `localhost`
   - **Port**: `5005`
4. Click **Debug**

### Debug Configuration Details

When `JAVA_DEBUG=true`, the server starts with the following JVM argument:

```
-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
```

- **`transport=dt_socket`**: Uses socket transport for debugging
- **`server=y`**: Server mode (waits for debugger to attach)
- **`suspend=n`**: Server starts immediately without waiting for debugger
- **`address=*:5005`**: Listens on all interfaces on port 5005

### Tips

- **Suspend on Start**: To make the server wait for the debugger before starting, you can modify the entrypoint script or use `JAVA_JVM_ARGS` with `suspend=y`
- **Remote Debugging**: If debugging from a different machine, ensure port `5005` is accessible and use the server's IP address instead of `localhost`
- **Performance**: Debug mode may slightly impact server performance. Disable it in production environments
- **Machine UUID**: When your docker-desktop / WSL installation does not have a machine-id yet. Run `uuidgen | sudo tee /etc/machine-id` in WSL  

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
