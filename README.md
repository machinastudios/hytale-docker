# Hytale Docker Setup

A Docker containerization setup for running a Hytale game server. This project provides a complete Docker Compose configuration with an automated build process to download and run the Hytale server.

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

## Project Structure

```
hytale-docker/
├── docker-compose.yml    # Docker Compose service definition
├── Dockerimage           # Dockerfile for building the Hytale server image
├── entrypoint.sh         # Entrypoint script that configures and starts the server
└── README.md             # This documentation file
```

## Prerequisites

- Docker Engine (version 20.10 or later)
- Docker Compose (version 1.29 or later)

## Quick Start

### Option 1: Using Pre-built Image (Recommended)

1. Pull the pre-built image:

```bash
docker pull ghcr.io/machinastudios/hytale-docker
```

2. Create a `docker-compose.yml` file (see Configuration section) or use Docker directly:

```bash
docker run -d \
  --name hytale \
  -p 5520:5520 \
  -v ./data:/hytale \
  ghcr.io/machinastudios/hytale-docker
```

### Option 2: Build from Source

1. Clone or download this repository
2. Start the server:

```bash
docker-compose up -d
```

3. The server will automatically download the Hytale server files on first build

### Checking Server Logs

```bash
# Using Docker Compose
docker-compose logs -f hytale

# Using Docker directly
docker logs -f hytale
```

## Configuration

### Environment Variables

The server can be configured using environment variables in `docker-compose.yml`:

#### `SERVER_ASSETS_ZIP`
- **Description**: URL or local file path to a ZIP file containing server assets
- **Default**: Empty (not used if not set)
- **Format**: Can be either a URL (e.g., `https://example.com/assets.zip`) or a local file path (e.g., `/hytale/assets.zip`)
- **Examples**: 
  - URL: `https://example.com/assets.zip`
  - Local file: `/hytale/custom-assets.zip`
- **Usage**: 
  - If set to a **local file path** (file exists), the server will use it directly
  - If set to a **URL**, the server will download the assets ZIP file before using it

#### `SERVER_ACCEPT_EARLY_PLUGINS`
- **Description**: Enable early plugin loading (accept plugins before they are fully validated)
- **Default**: `true`
- **Usage**: Set to any non-empty value to enable early plugin acceptance

#### `SERVER_BIND`
- **Description**: Server bind address and port
- **Default**: `0.0.0.0:5520`
- **Format**: `IP:PORT` or `0.0.0.0:PORT`
- **Usage**: Controls which network interface and port the server listens on

#### `SERVER_BACKUP_DIR`
- **Description**: Directory where server backups will be stored
- **Default**: `/hytale/backups`
- **Usage**: Must be set for backup functionality to work. The directory will be created automatically

#### `SERVER_BACKUP_INTERVAL`
- **Description**: Backup frequency in minutes
- **Default**: `10`
- **Usage**: Only used if `SERVER_BACKUP_DIR` is set. Defines how often backups are created

### Volume Mounts

The configuration mounts a local `./data` directory to `/hytale` in the container:

- **Host Path**: `./data`
- **Container Path**: `/hytale`
- **Purpose**: Persistent storage for server data, worlds, configurations, and backups

## File Descriptions

### docker-compose.yml

Defines the Docker Compose service configuration:

- **Service Name**: `hytale`
- **Build**: Builds from the local Dockerfile (`.`) or can be configured to use the pre-built image `ghcr.io/machinastudios/hytale-docker`
- **Port Mapping**: `5520:5520` (maps container port 5520 to host port 5520)
- **Volumes**: Maps `./data` to `/hytale` for persistent storage
- **Environment Variables**: Configures server behavior and settings

**Note**: To use the pre-built image instead of building from source, replace `build: .` with:
```yaml
image: ghcr.io/machinastudios/hytale-docker
```

### Dockerimage (Dockerfile)

The Docker image definition that:

1. **Base Image**: Uses `openjdk:22-jdk-slim` (OpenJDK 22)
2. **Setup Steps**:
   - Creates `/hytale` working directory
   - Installs `unzip` and `wget` utilities
   - Downloads the Hytale downloader from the official URL
   - Extracts and executes the downloader to fetch server files
   - Cleans up temporary files
3. **Exposed Port**: 5520 (default Hytale server port)
4. **Entrypoint**: Executes `entrypoint.sh` to start the server

### entrypoint.sh

The entrypoint script that runs when the container starts:

1. **Update Check**: Runs the Hytale downloader to check for server updates
2. **Asset Handling**: If `SERVER_ASSETS_ZIP` is set:
   - If it's a local file path (file exists), uses it directly
   - If it's a URL, downloads the assets ZIP file before using it
3. **Command Building**: Dynamically builds the Java command line based on environment variables:
   - `--assets`: Includes custom assets ZIP if provided
   - `--accept-early-plugins`: Enables early plugin loading if configured
   - `--bind`: Sets server bind address and port
   - `--backup`: Enables backup functionality
   - `--backup-dir`: Sets backup directory location
   - `--backup-frequency`: Sets backup interval in minutes
4. **Server Execution**: Launches `HytaleServer.jar` with the configured parameters

## Building the Image

### Using Pre-built Image

The easiest way is to use the pre-built image from GitHub Container Registry:

```bash
docker pull ghcr.io/machinastudios/hytale-docker
```

### Building from Source

To build the Docker image manually from the Dockerfile:

```bash
docker build -f Dockerimage -t hytale-server .
```

Or tag it with the same name as the pre-built image:

```bash
docker build -f Dockerimage -t ghcr.io/machinastudios/hytale-docker .
```

## Running the Container

### Using Docker Compose (Recommended)

#### Option 1: Using Pre-built Image

Update your `docker-compose.yml` to use the pre-built image:

```yaml
services:
    hytale:
        image: ghcr.io/machinastudios/hytale-docker
        ports:
            - "5520:5520"
        volumes:
            - ./data:/hytale
        environment:
            - SERVER_ACCEPT_EARLY_PLUGINS=true
            - SERVER_BIND=0.0.0.0:5520
            - SERVER_BACKUP_DIR=/hytale/backups
            - SERVER_BACKUP_INTERVAL=10
```

#### Option 2: Building from Source

The default `docker-compose.yml` builds from the local Dockerfile:

```bash
# Start in detached mode
docker-compose up -d

# Start with logs visible
docker-compose up
```

#### Common Commands

```bash
# Stop the server
docker-compose down

# Restart the server
docker-compose restart

# View logs
docker-compose logs -f hytale

# Pull latest image (if using pre-built)
docker-compose pull
```

### Using Docker Directly

#### With Pre-built Image (Recommended)

```bash
# Pull the image (if not already pulled)
docker pull ghcr.io/machinastudios/hytale-docker

# Run the container
docker run -d \
  --name hytale \
  -p 5520:5520 \
  -v ./data:/hytale \
  -e SERVER_ASSETS_ZIP="" \
  -e SERVER_ACCEPT_EARLY_PLUGINS="true" \
  -e SERVER_BIND="0.0.0.0:5520" \
  -e SERVER_BACKUP_DIR="/hytale/backups" \
  -e SERVER_BACKUP_INTERVAL="10" \
  ghcr.io/machinastudios/hytale-docker
```

#### Building and Running from Source

```bash
# Build the image
docker build -f Dockerimage -t hytale-server .

# Run the container
docker run -d \
  --name hytale \
  -p 5520:5520 \
  -v ./data:/hytale \
  -e SERVER_ASSETS_ZIP="" \
  -e SERVER_ACCEPT_EARLY_PLUGINS="true" \
  -e SERVER_BIND="0.0.0.0:5520" \
  -e SERVER_BACKUP_DIR="/hytale/backups" \
  -e SERVER_BACKUP_INTERVAL="10" \
  hytale-server
```

## Port Configuration

The default configuration maps port 5520 (default Hytale server port) from the container to the host. To change the port:

1. Modify `docker-compose.yml`:
   ```yaml
   ports:
       - "YOUR_PORT:5520"
   ```
2. Ensure `SERVER_BIND` matches if you want the server to listen on a specific interface

## Data Persistence

All server data is stored in the `./data` directory on your host machine:

- **Server Files**: Configuration files, worlds, player data
- **Backups**: Automated backups (if enabled) in `./data/backups`
- **Logs**: Server logs and console output

**Important**: Ensure the `./data` directory has proper permissions for the container to write files.

## Backup System

The backup system is automatically configured when `SERVER_BACKUP_DIR` is set:

- **Backups Location**: `/hytale/backups` (mapped to `./data/backups` on host)
- **Backup Interval**: Configurable via `SERVER_BACKUP_INTERVAL` (in minutes)
- **Automatic Creation**: Backups are created automatically at the specified interval

## Troubleshooting

### Server Won't Start

1. Check container logs:
   ```bash
   docker-compose logs hytale
   ```

2. Verify Java is working:
   ```bash
   docker-compose exec hytale java -version
   ```

3. Ensure the downloader completed successfully:
   ```bash
   docker-compose exec hytale ls -la /hytale/
   ```

### Port Already in Use

If port 5520 is already in use:

1. Change the port mapping in `docker-compose.yml`
2. Update firewall rules if necessary
3. Ensure no other Hytale servers are running

### Permission Issues

If the server cannot write to the data directory:

```bash
# On Linux/macOS
chmod -R 777 ./data

# Or set ownership to the Docker user
sudo chown -R 1000:1000 ./data
```

### Server Not Updating

The entrypoint script runs the downloader update check on every container start. If updates aren't being applied:

1. Rebuild the image to get the latest downloader:
   ```bash
   docker-compose build --no-cache
   docker-compose up -d
   ```

2. Manually check for updates inside the container:
   ```bash
   docker-compose exec hytale /hytale/hytale-downloader -check-update
   ```

## Maintenance

### Updating the Server

The server automatically checks for updates on startup. To force a rebuild:

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Cleaning Up

To remove all containers, volumes, and data (**WARNING**: This deletes server data):

```bash
docker-compose down -v
rm -rf ./data
```

To keep data but remove containers:

```bash
docker-compose down
```

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
