#!/bin/bash
# Entrypoint for the Hytale server - dockerized

# Set the downloader URL
DOWNLOADER_URL=https://downloader.hytale.com/hytale-downloader.zip
DOWNLOADER_FILE=hytale-downloader.zip
APP_DIR="${APP_DIR:-/hytale}"

# Go to the app directory
cd $APP_DIR

# Run the updater
./$hytale-downloader -check-update

# Prepare the command line
COMMAND_LINE="java -jar $APP_DIR/HytaleServer.jar"

# If the SERVER_ASSETS_ZIP environment variable is set
if [ -n "$SERVER_ASSETS_ZIP" ]; then
    # If it's a local file, add it to the command line
    if [ -f "$SERVER_ASSETS_ZIP" ]; then
        COMMAND_LINE="$COMMAND_LINE --assets $SERVER_ASSETS_ZIP"
    else
        # Download the assets zip
        wget -O $APP_DIR/assets.zip $SERVER_ASSETS_ZIP

        # Add the assets zip to the command line
        COMMAND_LINE="$COMMAND_LINE --assets $APP_DIR/assets.zip"
    fi
fi

# If the SERVER_ACCEPT_EARLY_PLUGINS environment variable is set
if [ -n "$SERVER_ACCEPT_EARLY_PLUGINS" ]; then
    # Add the accept early plugins flag to the command line
    COMMAND_LINE="$COMMAND_LINE --accept-early-plugins"
fi

# If the SERVER_BIND environment variable is set
if [ -n "$SERVER_BIND" ]; then
    # Add the bind flag to the command line
    COMMAND_LINE="$COMMAND_LINE --bind $SERVER_BIND"
fi

# If the SERVER_BACKUP or SERVER_BACKUP_DIR environment variable is set
if [ -n "$SERVER_BACKUP" ] || [ -n "$SERVER_BACKUP_DIR" ] then
    # Add the backup flag to the command line
    COMMAND_LINE="$COMMAND_LINE --backup"

    # If the SERVER_BACKUP_DIR environment variable is set
    if [ -n "$SERVER_BACKUP_DIR" ]; then
        # Add the backup directory flag to the command line
        COMMAND_LINE="$COMMAND_LINE --backup-dir $SERVER_BACKUP_DIR"
    fi

    # If the SERVER_BACKUP_INTERVAL environment variable is set
    if [ -n "$SERVER_BACKUP_INTERVAL" ]; then
        # Add the backup interval flag to the command line
        COMMAND_LINE="$COMMAND_LINE --backup-frequency $SERVER_BACKUP_INTERVAL"
    fi
fi

# Run the server
$COMMAND_LINE