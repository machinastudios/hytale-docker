#!/bin/bash
# Entrypoint for the Hytale server - dockerized

# For now, we will ignore the update check
# because we don't know how to handle them
DOWNLOADER_SKIP_UPDATE_CHECK="true"

# Set the app directory
APP_DIR="${APP_DIR:-/hytale}"

# Go to the app directory
cd $APP_DIR

# Prepare downloader command line
DOWNLOADER_CMD="/bin/hytale-downloader"

# Create a tmp file
DOWNLOADER_TMP_FILE="/tmp/server-files.zip"

# Delete the tmp file on exit
trap "rm -f $DOWNLOADER_TMP_FILE" EXIT

# Build downloader arguments
DOWNLOADER_ARGS="-download-path $DOWNLOADER_TMP_FILE"

# If DOWNLOADER_CREDENTIALS_PATH is set, add credentials path
if [ -n "$DOWNLOADER_CREDENTIALS_PATH" ]; then
    DOWNLOADER_ARGS="$DOWNLOADER_ARGS -credentials-path $DOWNLOADER_CREDENTIALS_PATH"
fi

# If DOWNLOADER_DOWNLOAD_PATH is set, add download path
if [ -n "$DOWNLOADER_DOWNLOAD_PATH" ]; then
    DOWNLOADER_ARGS="$DOWNLOADER_ARGS -download-path $DOWNLOADER_DOWNLOAD_PATH"
fi

# If DOWNLOADER_PATCHLINE is set, add patchline
if [ -n "$DOWNLOADER_PATCHLINE" ]; then
    DOWNLOADER_ARGS="$DOWNLOADER_ARGS -patchline $DOWNLOADER_PATCHLINE"
fi

# Run the downloader to download/update server files
# Check if HytaleServer.jar exists - if not, run downloader even if skip is set
if [ ! -f "$APP_DIR/HytaleServer.jar" ] || [ -z "$DOWNLOADER_SKIP_UPDATE_CHECK" ]; then
    if [ -z "$DOWNLOADER_SKIP_UPDATE_CHECK" ]; then
        echo "checking for updates..."
    else
        echo "running the downloader for the first time..."
    fi

    # If a server-files.zip file is not found, exit
    if [ ! -f "$DOWNLOADER_TMP_FILE" ]; then
        echo "downloading server files..."

        # Run the downloader to download/update server files
        $DOWNLOADER_CMD $DOWNLOADER_ARGS
    else
        echo "server files already downloaded, skipping downloader"
    fi

    # If the update failed, exit
    if [ $? -ne 0 ]; then
        echo "failed to update server files"
        exit 1
    fi

    # If server files where downloaded
    if [ -f "$DOWNLOADER_TMP_FILE" ]; then
        echo "unzipping server files..."

        # Create a tmp folder
        TMP_FOLDER=$(mktemp -d)

        # Delete the tmp folder on exit
        trap "rm -rf $TMP_FOLDER" EXIT

        # Unzip the server files
        # They're inside the "Server" folder in the zip file
        # and need to go to the root directory
        unzip -q $DOWNLOADER_TMP_FILE  -d $TMP_FOLDER

        # Copy the `Server` folder to the app directory
        cp -r $TMP_FOLDER/Server/* $APP_DIR

        # If no assets zip is found specified, use the default one
        if [ -z "$SERVER_ASSETS_ZIP" ]; then
            # Set the assets zip to the default one
            SERVER_ASSETS_ZIP=$TMP_FOLDER/Assets.zip

            # Copy the `Assets.zip` file to the app directory
            cp $TMP_FOLDER/Assets.zip $APP_DIR/Assets.zip
        fi

        if [ $? -ne 0 ]; then
            echo "failed to unzip server files"
            exit 1
        fi

        # Delete the server files zip
        rm $DOWNLOADER_TMP_FILE
    fi
fi

echo "initializing server..."

# Prepare the command line
COMMAND_LINE="java -jar $APP_DIR/HytaleServer.jar"

# If a custom assets zip is specified, use it
if [ -n "$SERVER_ASSETS_ZIP" ]; then
    # If it's a local file, add it to the command line
    if [ -f "$SERVER_ASSETS_ZIP" ]; then
        COMMAND_LINE="$COMMAND_LINE --assets $SERVER_ASSETS_ZIP"
    else
        # Download the assets zip
        wget -O $APP_DIR/Assets.zip $SERVER_ASSETS_ZIP

        # Add the assets zip to the command line
        COMMAND_LINE="$COMMAND_LINE --assets $APP_DIR/Assets.zip"
    fi
else
    # Add the assets zip to the command line
    COMMAND_LINE="$COMMAND_LINE --assets $APP_DIR/Assets.zip"
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

# Default backup directory and interval
SERVER_BACKUP_DIR="${SERVER_BACKUP_DIR:-/hytale/backups}"
SERVER_BACKUP_INTERVAL="${SERVER_BACKUP_INTERVAL:-10}"

# Add the backup flag to the command line
COMMAND_LINE="$COMMAND_LINE --backup --backup-dir $SERVER_BACKUP_DIR --backup-frequency $SERVER_BACKUP_INTERVAL"

# Run the server
$COMMAND_LINE
