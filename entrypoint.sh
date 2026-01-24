#!/bin/bash
# Entrypoint for the Hytale server - dockerized

# Display any errors when exiting
set -e

# Import scripts
source /src/logger.sh
source /src/authorization.sh
source /src/variables.sh

# Go to the app directory
cd $APP_DIR

# Prepare downloader command line
DOWNLOADER_CMD="/bin/hytale-downloader"
DOWNLOADER_TMP_FILE="/tmp/server-files.zip"
DOWNLOADER_CREDENTIALS_PATH="${DOWNLOADER_CREDENTIALS_PATH:-$APP_DIR/.hytale-downloader-credentials.json}"

# Delete the tmp file on exit
trap "rm -f $DOWNLOADER_TMP_FILE" EXIT

# Build downloader arguments
DOWNLOADER_ARGS="-download-path $DOWNLOADER_TMP_FILE"

# If DOWNLOADER_CREDENTIALS_PATH is set and the file exists, add credentials path
if [ "$DOWNLOADER_CREDENTIALS_PATH" != "" ]; then
    DOWNLOADER_ARGS="$DOWNLOADER_ARGS -credentials-path $DOWNLOADER_CREDENTIALS_PATH"
fi

# If DOWNLOADER_DOWNLOAD_PATH is set, add download path
if [ "$DOWNLOADER_DOWNLOAD_PATH" != "" ]; then
    DOWNLOADER_ARGS="$DOWNLOADER_ARGS -download-path $DOWNLOADER_DOWNLOAD_PATH"
fi

# If DOWNLOADER_PATCHLINE is set, add patchline
if [ -n "$DOWNLOADER_PATCHLINE" ]; then
    DOWNLOADER_ARGS="$DOWNLOADER_ARGS -patchline $DOWNLOADER_PATCHLINE"
fi

# Check for updates in the downloder itself
if ! $DOWNLOADER_CMD -check-update; then
    log_error "Failed to check for updates in the downloader"
    log_debug "Downloader command: $DOWNLOADER_CMD $DOWNLOADER_ARGS"
    exit 1
else
    log_info "Downloader is up to date"
fi

# Run the authorization check
if ! authorization_check; then
    log_error "Failed to authorize the downloader"
    exit 1
else
    log_info "Authorized the downloader"
fi

# Run the downloader to download/update server files
# Check if HytaleServer.jar and VERSION_FILE exist - if not, run downloader 
if [ ! -f "$APP_DIR/HytaleServer.jar" ] || [ ! -f "$VERSION_FILE" ]; then
    log_info "Running the downloader for the first time..."

    # If a server-files.zip file is not found, exit
    if [ ! -f "$DOWNLOADER_TMP_FILE" ]; then
        log_info "Downloading server files (this may take a while, please wait)..."

        # Run the downloader to download/update server files
        $DOWNLOADER_CMD $DOWNLOADER_ARGS

        # If the downloader failed, exit
        if [ $? -ne 0 ]; then
            log_error "Failed to update server files"
            exit 1
        fi
    else
        log_info "Server files already downloaded, skipping downloader"
    fi

    # If the update failed, exit
    if [ $? -ne 0 ]; then
        log_error "Failed to update server files"
        exit 1
    fi

    # If server files where downloaded
    if [ -f "$DOWNLOADER_TMP_FILE" ]; then
        log_info "Unzipping server files..."

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
            log_error "Failed to unzip server files"
            exit 1
        fi

        # Delete the server files zip
        rm $DOWNLOADER_TMP_FILE
    fi

    # Get the installed version
    INSTALLED_VERSION=$($DOWNLOADER_CMD -print-version)

    log_info "Storing current version ($INSTALLED_VERSION) to $VERSION_FILE"
    echo "$INSTALLED_VERSION" > "$VERSION_FILE"
else
    # If should check for updates
    if [ "$DOWNLOADER_SKIP_UPDATE_CHECK" != "true" ]; then
        log_info "Checking for server updates..."

        # Get the latest version
        LATEST_VERSION=$($DOWNLOADER_CMD -print-version | tail -n 1 | tr -d '\r')

        # Get the current version
        CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")

        log_info "Latest version available: $LATEST_VERSION"
        log_debug "Current version installed: $CURRENT_VERSION"

        # If "unknown" is returned, exit
        if [ "$CURRENT_VERSION" = "unknown" ]; then
            log_error "Current version is unknown, are there any configurations missing?"
            log_debug "Version file: $VERSION_FILE"
            log_debug "Downloader command: $DOWNLOADER_CMD $DOWNLOADER_ARGS"
            exit 1
        fi

        # If the latest version is not the same as the current version
        if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
            log_info "Updating server from version $CURRENT_VERSION to $LATEST_VERSION"
            $DOWNLOADER_CMD $DOWNLOADER_ARGS

            # If the update failed, exit
            if [ $? -ne 0 ]; then
                log_error "Failed to update server files"
                exit 1
            fi

             # If server files where downloaded
            if [ -f "$DOWNLOADER_TMP_FILE" ]; then
                log_info "Unzipping server files..."
            fi

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
                log_error "Failed to unzip server files"
                exit 1
            fi

            # Delete the server files zip
            rm $DOWNLOADER_TMP_FILE
            log_info "Storing current version ($LATEST_VERSION) to $VERSION_FILE"
            echo $LATEST_VERSION > $VERSION_FILE
        else
            log_info "Server is up to date, no update needed"
        fi
    else
        log_info "Skipping server update check..."
    fi
fi

log_info "Initializing server..."

# Configure server settings from environment variables
CONFIG_FILE="$APP_DIR/config.json"

# Update config.json if environment variables are set.
# If config.json doesn't exist yet, create it first (so we can inject values before `java -jar`).
NEED_CONFIG_UPDATE=false
if [ -n "$SERVER_NAME" ] || [ -n "$SERVER_MOTD" ] || [ -n "$SERVER_PASSWORD" ] || [ -n "$SERVER_MAX_PLAYERS" ] || [ -n "$SERVER_MAX_VIEW_RADIUS" ]; then
    NEED_CONFIG_UPDATE=true
fi

if [ "$NEED_CONFIG_UPDATE" = true ]; then
    # Check if jq is available (should be installed in Dockerfile)
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found. Cannot update config.json. Please install jq in the Dockerfile."
    else
        # Create config.json if missing
        if [ ! -f "$CONFIG_FILE" ]; then
            log_info "config.json not found at $CONFIG_FILE - creating a new one..."
            jq -n '{}' > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update ServerName if SERVER_NAME is set
        if [ -n "$SERVER_NAME" ]; then
            log_info "Setting ServerName to: $SERVER_NAME"
            jq --arg name "$SERVER_NAME" '.ServerName = $name' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update MOTD if SERVER_MOTD is set
        if [ -n "$SERVER_MOTD" ]; then
            log_info "Setting MOTD to: $SERVER_MOTD"
            jq --arg motd "$SERVER_MOTD" '.MOTD = $motd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update Password if SERVER_PASSWORD is set
        if [ -n "$SERVER_PASSWORD" ]; then
            log_info "Setting server password"
            jq --arg password "$SERVER_PASSWORD" '.Password = $password' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update MaxPlayers if SERVER_MAX_PLAYERS is set
        if [ -n "$SERVER_MAX_PLAYERS" ]; then
            log_info "Setting MaxPlayers to: $SERVER_MAX_PLAYERS"
            jq --argjson max "$SERVER_MAX_PLAYERS" '.MaxPlayers = $max' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update MaxViewRadius if SERVER_MAX_VIEW_RADIUS is set (numeric)
        if [ -n "$SERVER_MAX_VIEW_RADIUS" ]; then
            log_info "Setting MaxViewRadius to: $SERVER_MAX_VIEW_RADIUS"
            jq --argjson radius "$SERVER_MAX_VIEW_RADIUS" '.MaxViewRadius = $radius' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi
    fi
fi

# Prepare the command line
COMMAND_LINE="java"

# Add memory settings if specified
if [ -n "$SERVER_MIN_RAM" ]; then
    COMMAND_LINE="$COMMAND_LINE -Xms$SERVER_MIN_RAM"
fi

if [ -n "$SERVER_MAX_RAM" ]; then
    COMMAND_LINE="$COMMAND_LINE -Xmx$SERVER_MAX_RAM"
fi

# If Java debug is enabled, add the debug flag to the command line
if [ "$JAVA_DEBUG" = "true" ]; then
    COMMAND_LINE="$COMMAND_LINE -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
fi

# Add custom JVM arguments if specified
if [ -n "$JAVA_JVM_ARGS" ]; then
    COMMAND_LINE="$COMMAND_LINE $JAVA_JVM_ARGS"
fi

# Add the jar file to the command line
COMMAND_LINE="$COMMAND_LINE -jar $APP_DIR/HytaleServer.jar"

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

# Check for session token (environment variable takes precedence)
if [ -n "$HYTALE_SERVER_SESSION_TOKEN" ]; then
    SESSION_TOKEN="$HYTALE_SERVER_SESSION_TOKEN"
    log_info "Using session token from HYTALE_SERVER_SESSION_TOKEN environment variable"
elif [ -n "$SERVER_AUTH_ENABLED" ] && [ -f "$TOKEN_FILE" ]; then
    # Get sessionToken from tokens.json (Hytale server EdDSA token)
    SESSION_TOKEN=$(jq -r '.sessionToken // empty' "$TOKEN_FILE" 2>/dev/null)
    if [ -n "$SESSION_TOKEN" ] && [ "$SESSION_TOKEN" != "null" ]; then
        log_info "Using session token from $TOKEN_FILE"
    fi
fi

# Check for identity token (environment variable takes precedence)
if [ -n "$HYTALE_SERVER_IDENTITY_TOKEN" ]; then
    IDENTITY_TOKEN="$HYTALE_SERVER_IDENTITY_TOKEN"
    log_info "Using identity token from HYTALE_SERVER_IDENTITY_TOKEN environment variable"
elif [ -n "$SERVER_AUTH_ENABLED" ] && [ -f "$TOKEN_FILE" ]; then
    # Get identityToken from tokens.json (Hytale server EdDSA token)
    IDENTITY_TOKEN=$(jq -r '.identityToken // empty' "$TOKEN_FILE" 2>/dev/null)
    if [ -n "$IDENTITY_TOKEN" ] && [ "$IDENTITY_TOKEN" != "null" ]; then
        log_info "Using identity token from $TOKEN_FILE"
    fi
fi

# Export environment variables for Method C (if tokens are available)
if [ -n "$SESSION_TOKEN" ]; then
    export HYTALE_SERVER_SESSION_TOKEN="$SESSION_TOKEN"
fi

if [ -n "$IDENTITY_TOKEN" ]; then
    export HYTALE_SERVER_IDENTITY_TOKEN="$IDENTITY_TOKEN"
fi

if [ -n "$HYTALE_SERVER_AUDIENCE" ]; then
    export HYTALE_SERVER_AUDIENCE="$HYTALE_SERVER_AUDIENCE"
fi

# Run the server
$COMMAND_LINE
