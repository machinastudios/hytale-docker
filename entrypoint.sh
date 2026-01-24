#!/bin/bash
# Entrypoint for the Hytale server - dockerized

# Display any errors when exiting
set -e

# Directories
VERSION_FILE="${VERSION_FILE:-/hytale/VERSION}"
APP_DIR="${APP_DIR:-/hytale}"

# Configuration defaults
SERVER_AUTH_ENABLED="${SERVER_AUTH_ENABLED:-true}"
SERVER_ASSETS_ZIP="${SERVER_ASSETS_ZIP:-}"
SERVER_BACKUP_DIR="${SERVER_BACKUP_DIR:-/hytale/backups}"
SERVER_BACKUP_INTERVAL="${SERVER_BACKUP_INTERVAL:-10}"
DOWNLOADER_SKIP_UPDATE_CHECK="${SEVER_SKIP_UPDATE_CHECK:-false}"
JAVA_DEBUG="${JAVA_DEBUG:-false}"

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
# Check if HytaleServer.jar exists - if not, run downloader 
if [ ! -f "$APP_DIR/HytaleServer.jar" ]; then
    echo "running the downloader for the first time..."

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
    INSTALLED_VERSION=$($DOWNLOADER_CMD -print-version)
    echo "storing current version ($INSTALLED_VERSION) to $VERSION_FILE"
    echo "$INSTALLED_VERSION" > "$VERSION_FILE"
else
    if [ "$DOWNLOADER_SKIP_UPDATE_CHECK" != "true" ]; then
        echo "checking for server updates..."

        NEWESTVERSION=$($DOWNLOADER_CMD -print-version | tail -n 1 | tr -d '\r')
        CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")

        echo "newest version available: $NEWESTVERSION"
        echo "current version installed: $CURRENT_VERSION"

        if [ "$NEWESTVERSION" != "$CURRENT_VERSION" ]; then
            echo "updating server from version $CURRENT_VERSION to $NEWESTVERSION"
            $DOWNLOADER_CMD $DOWNLOADER_ARGS

            # If the update failed, exit
            if [ $? -ne 0 ]; then
                echo "failed to update server files"
                exit 1
            fi

             # If server files where downloaded
            if [ -f "$DOWNLOADER_TMP_FILE" ]; then
                echo "unzipping server files..."
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
                echo "failed to unzip server files"
                exit 1
            fi

            # Delete the server files zip
            rm $DOWNLOADER_TMP_FILE
            echo "storing current version ($NEWESTVERSION) to $VERSION_FILE"
            echo $NEWESTVERSION > $VERSION_FILE
        else
            echo "server is up to date, no update needed"
        fi
    else
        echo "skipping server update check..."
    fi
fi

echo "initializing server..."

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
        echo "WARNING: jq not found. Cannot update config.json. Please install jq in the Dockerfile."
    else
        # Create config.json if missing
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "config.json not found at $CONFIG_FILE - creating a new one..."
            jq -n '{}' > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update ServerName if SERVER_NAME is set
        if [ -n "$SERVER_NAME" ]; then
            echo "Setting ServerName to: $SERVER_NAME"
            jq --arg name "$SERVER_NAME" '.ServerName = $name' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update MOTD if SERVER_MOTD is set
        if [ -n "$SERVER_MOTD" ]; then
            echo "Setting MOTD to: $SERVER_MOTD"
            jq --arg motd "$SERVER_MOTD" '.MOTD = $motd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update Password if SERVER_PASSWORD is set
        if [ -n "$SERVER_PASSWORD" ]; then
            echo "Setting server password"
            jq --arg password "$SERVER_PASSWORD" '.Password = $password' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update MaxPlayers if SERVER_MAX_PLAYERS is set
        if [ -n "$SERVER_MAX_PLAYERS" ]; then
            echo "Setting MaxPlayers to: $SERVER_MAX_PLAYERS"
            jq --argjson max "$SERVER_MAX_PLAYERS" '.MaxPlayers = $max' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi

        # Update MaxViewRadius if SERVER_MAX_VIEW_RADIUS is set (numeric)
        if [ -n "$SERVER_MAX_VIEW_RADIUS" ]; then
            echo "Setting MaxViewRadius to: $SERVER_MAX_VIEW_RADIUS"
            jq --argjson radius "$SERVER_MAX_VIEW_RADIUS" '.MaxViewRadius = $radius' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi
    fi
fi

# Device Code Flow (RFC 8628) Authentication
# Token storage location (single file with all tokens)
TOKEN_FILE="$APP_DIR/tokens.json"

# OAuth2 endpoints
CLIENT_ID="hytale-server"
DEVICE_AUTH_URL="https://oauth.accounts.hytale.com/oauth2/device/auth"
TOKEN_URL="https://oauth.accounts.hytale.com/oauth2/token"
SCOPE="openid offline auth:server"
PROFILES_URL="https://account-data.hytale.com/my-account/get-profiles"
SESSION_URL="https://sessions.hytale.com/game-session/new"

# Function to perform Device Code Flow authentication
authenticate_device_flow() {
    echo "==================================================================="
    echo "DEVICE CODE FLOW AUTHENTICATION"
    echo "==================================================================="
    
    # Request device code
    echo "Requesting device code..."
    AUTH_RESPONSE=$(curl -s -X POST "$DEVICE_AUTH_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$CLIENT_ID" \
        -d "scope=$SCOPE")
    
    # Extract values using jq
    DEVICE_CODE=$(echo "$AUTH_RESPONSE" | jq -r '.device_code // empty')
    USER_CODE=$(echo "$AUTH_RESPONSE" | jq -r '.user_code // empty')
    VERIFICATION_URI=$(echo "$AUTH_RESPONSE" | jq -r '.verification_uri // empty')
    VERIFICATION_URI_COMPLETE=$(echo "$AUTH_RESPONSE" | jq -r '.verification_uri_complete // empty')
    INTERVAL=$(echo "$AUTH_RESPONSE" | jq -r '.interval // 5')
    EXPIRES_IN=$(echo "$AUTH_RESPONSE" | jq -r '.expires_in // 900')
    
    # Default interval if not provided
    INTERVAL=${INTERVAL:-5}
    EXPIRES_IN=${EXPIRES_IN:-900}
    
    if [ -z "$DEVICE_CODE" ] || [ -z "$USER_CODE" ]; then
        echo "ERROR: Failed to obtain device code. Response: $AUTH_RESPONSE"
        return 1
    fi
    
    # Display instructions to user
    echo ""
    echo "Please visit the following URL to authenticate:"
    echo "$VERIFICATION_URI_COMPLETE"
    echo ""
    echo "Or visit:"
    echo "$VERIFICATION_URI"
    echo "And enter the code: $USER_CODE"
    echo ""
    echo "Waiting for authorization (expires in $EXPIRES_IN seconds)..."
    echo "==================================================================="
    
    # Poll for token
    ELAPSED=0
    while [ $ELAPSED -lt $EXPIRES_IN ]; do
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        
        TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=$CLIENT_ID" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
            -d "device_code=$DEVICE_CODE")
        
        ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')
        
        if [ "$ERROR" = "authorization_pending" ]; then
            echo "Still waiting for authorization... ($ELAPSED/$EXPIRES_IN seconds)"
            continue
        elif [ "$ERROR" = "slow_down" ]; then
            INTERVAL=$((INTERVAL + 5))
            echo "Rate limited, slowing down polling..."
            continue
        elif [ -n "$ERROR" ] && [ "$ERROR" != "null" ]; then
            echo "ERROR: Authorization failed: $ERROR"
            echo "Response: $TOKEN_RESPONSE"
            return 1
        else
            # Success - extract tokens
            ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
            ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token // empty')
            REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')
            
            if [ -z "$ACCESS_TOKEN" ]; then
                echo "ERROR: Failed to obtain access token. Response: $TOKEN_RESPONSE"
                return 1
            fi
            
            # Step 4: Get Available Profiles
            echo "Getting available profiles..."
            PROFILES_RESPONSE=$(curl -s -X GET "$PROFILES_URL" \
                -H "Authorization: Bearer $ACCESS_TOKEN")
            
            # Extract profile UUID (use first profile or owner UUID if available)
            PROFILE_UUID=$(echo "$PROFILES_RESPONSE" | jq -r '.profiles[0].uuid // .owner // empty')
            
            # Use HYTALE_SERVER_OWNER_UUID if set, otherwise use profile UUID
            if [ -n "$HYTALE_SERVER_OWNER_UUID" ]; then
                PROFILE_UUID="$HYTALE_SERVER_OWNER_UUID"
                echo "Using profile UUID from HYTALE_SERVER_OWNER_UUID: $PROFILE_UUID"
            elif [ -n "$PROFILE_UUID" ]; then
                echo "Using profile UUID: $PROFILE_UUID"
            else
                echo "WARNING: Could not get profile UUID. Response: $PROFILES_RESPONSE"
                echo "You may need to set HYTALE_SERVER_OWNER_UUID environment variable"
                return 1
            fi
            
            # Step 5: Create Game Session to get EdDSA tokens (sessionToken and identityToken)
            echo "Creating game session..."
            SESSION_RESPONSE=$(curl -s -X POST "$SESSION_URL" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"uuid\":\"$PROFILE_UUID\"}")
            
            # Extract sessionToken and identityToken (EdDSA tokens)
            SESSION_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.sessionToken // empty')
            IDENTITY_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.identityToken // empty')
            EXPIRES_AT=$(echo "$SESSION_RESPONSE" | jq -r '.expiresAt // empty')
            
            if [ -z "$SESSION_TOKEN" ] || [ -z "$IDENTITY_TOKEN" ]; then
                echo "ERROR: Failed to get sessionToken and identityToken. Response: $SESSION_RESPONSE"
                return 1
            fi
            
            # Save tokens to single file (Hytale server EdDSA tokens)
            jq -n \
                --arg session_token "$SESSION_TOKEN" \
                --arg identity_token "$IDENTITY_TOKEN" \
                --arg refresh_token "$REFRESH_TOKEN" \
                --arg access_token "$ACCESS_TOKEN" \
                --arg profile_uuid "$PROFILE_UUID" \
                --arg expires_at "$EXPIRES_AT" \
                '{
                    "sessionToken": $session_token,
                    "identityToken": $identity_token,
                    "refresh_token": $refresh_token,
                    "access_token": $access_token,
                    "profile_uuid": $profile_uuid,
                    "expires_at": $expires_at
                }' > "$TOKEN_FILE"
            
            echo ""
            echo "==================================================================="
            echo "AUTHORIZATION SUCCESSFUL!"
            echo "Tokens saved to $APP_DIR"
            echo "==================================================================="
            return 0
        fi
    done
    
    echo "ERROR: Authorization timed out after $EXPIRES_IN seconds"
    return 1
}

# Function to refresh tokens using refresh token
refresh_tokens() {
    if [ ! -f "$TOKEN_FILE" ]; then
        return 1
    fi
    
    REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$TOKEN_FILE")
    PROFILE_UUID=$(jq -r '.profile_uuid // empty' "$TOKEN_FILE")
    
    if [ -z "$REFRESH_TOKEN" ]; then
        return 1
    fi
    
    echo "Refreshing OAuth2 tokens..."
    TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$CLIENT_ID" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$REFRESH_TOKEN")
    
    ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')
    
    if [ -n "$ERROR" ] && [ "$ERROR" != "null" ]; then
        echo "Token refresh failed: $ERROR"
        return 1
    fi
    
    # Extract OAuth2 tokens
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
    NEW_REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')
    ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token // empty')
    
    if [ -z "$ACCESS_TOKEN" ]; then
        return 1
    fi
    
    # Use existing refresh_token if new one not provided
    if [ -z "$NEW_REFRESH_TOKEN" ] || [ "$NEW_REFRESH_TOKEN" = "null" ]; then
        NEW_REFRESH_TOKEN="$REFRESH_TOKEN"
    fi
    
    # Use HYTALE_SERVER_OWNER_UUID if set, otherwise use stored profile UUID
    if [ -n "$HYTALE_SERVER_OWNER_UUID" ]; then
        PROFILE_UUID="$HYTALE_SERVER_OWNER_UUID"
    fi
    
    if [ -z "$PROFILE_UUID" ] || [ "$PROFILE_UUID" = "null" ]; then
        # Get profile UUID if not stored
        echo "Getting available profiles..."
        PROFILES_RESPONSE=$(curl -s -X GET "$PROFILES_URL" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        PROFILE_UUID=$(echo "$PROFILES_RESPONSE" | jq -r '.profiles[0].uuid // .owner // empty')
    fi
    
    if [ -z "$PROFILE_UUID" ] || [ "$PROFILE_UUID" = "null" ]; then
        echo "WARNING: Could not get profile UUID, tokens may not work"
        # Save OAuth2 tokens anyway
        jq -n \
            --arg refresh_token "$NEW_REFRESH_TOKEN" \
            --arg access_token "$ACCESS_TOKEN" \
            --arg id_token "$ID_TOKEN" \
            '{
                "refresh_token": $refresh_token,
                "access_token": $access_token,
                "id_token": $id_token
            }' > "$TOKEN_FILE"
        return 0
    fi
    
    # Step 5: Create Game Session to get EdDSA tokens (sessionToken and identityToken)
    echo "Creating new game session..."
    SESSION_RESPONSE=$(curl -s -X POST "$SESSION_URL" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"uuid\":\"$PROFILE_UUID\"}")
    
    # Extract sessionToken and identityToken (EdDSA tokens)
    SESSION_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.sessionToken // empty')
    IDENTITY_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.identityToken // empty')
    EXPIRES_AT=$(echo "$SESSION_RESPONSE" | jq -r '.expiresAt // empty')
    
    if [ -z "$SESSION_TOKEN" ] || [ -z "$IDENTITY_TOKEN" ]; then
        echo "WARNING: Failed to get new session tokens, using OAuth2 tokens only"
        # Save OAuth2 tokens anyway
        jq -n \
            --arg refresh_token "$NEW_REFRESH_TOKEN" \
            --arg access_token "$ACCESS_TOKEN" \
            --arg id_token "$ID_TOKEN" \
            '{
                "refresh_token": $refresh_token,
                "access_token": $access_token,
                "id_token": $id_token
            }' > "$TOKEN_FILE"
        return 0
    fi
    
    # Save all tokens (Hytale server EdDSA tokens + OAuth2 tokens)
    jq -n \
        --arg session_token "$SESSION_TOKEN" \
        --arg identity_token "$IDENTITY_TOKEN" \
        --arg refresh_token "$NEW_REFRESH_TOKEN" \
        --arg access_token "$ACCESS_TOKEN" \
        --arg profile_uuid "$PROFILE_UUID" \
        --arg expires_at "$EXPIRES_AT" \
        '{
            "sessionToken": $session_token,
            "identityToken": $identity_token,
            "refresh_token": $refresh_token,
            "access_token": $access_token,
            "profile_uuid": $profile_uuid,
            "expires_at": $expires_at
        }' > "$TOKEN_FILE"
    
    echo "Tokens refreshed successfully"
    return 0
}

# Check if authentication is needed
# Only authenticate if SERVER_AUTH_ENABLED is set and tokens don't exist
if [ -n "$SERVER_AUTH_ENABLED" ]; then
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "Authentication required..."

        authenticate_device_flow

        if [ $? -ne 0 ]; then
            echo "WARNING: Authentication failed. Server may not start properly."
            echo "You can disable authentication by removing SERVER_AUTH_ENABLED or"
            echo "manually authenticate using: /auth login device"
        fi
    else
        echo "Checking token validity..."
        
        # Check if token is expired
        EXPIRES_AT=$(jq -r '.expires_at // empty' "$TOKEN_FILE" 2>/dev/null)
        SESSION_TOKEN=$(jq -r '.sessionToken // empty' "$TOKEN_FILE" 2>/dev/null)
        
        NEED_REFRESH=false
        
        if [ -n "$EXPIRES_AT" ] && [ "$EXPIRES_AT" != "null" ] && [ "$EXPIRES_AT" != "" ]; then
            # Check if expires_at is in the past (format: 2026-01-07T15:00:00Z)
            CURRENT_TIMESTAMP=$(date -u +%s)
            EXPIRES_TIMESTAMP=$(date -u -d "$EXPIRES_AT" +%s 2>/dev/null || echo "0")
            
            if [ "$EXPIRES_TIMESTAMP" -gt 0 ] && [ "$CURRENT_TIMESTAMP" -ge "$EXPIRES_TIMESTAMP" ]; then
                echo "Token expired at $EXPIRES_AT, refreshing..."
                NEED_REFRESH=true
            fi
        elif [ -z "$SESSION_TOKEN" ] || [ "$SESSION_TOKEN" = "null" ] || [ "$SESSION_TOKEN" = "" ]; then
            # No session token, need to refresh
            echo "No valid session token found, refreshing..."
            NEED_REFRESH=true
        fi
        
        # Try to refresh tokens
        REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$TOKEN_FILE" 2>/dev/null)
        if [ -n "$REFRESH_TOKEN" ] && [ "$REFRESH_TOKEN" != "null" ]; then
            if [ "$NEED_REFRESH" = true ]; then
                if refresh_tokens; then
                    echo "Tokens refreshed successfully"
                else
                    echo "Token refresh failed, attempting full authentication..."
                    authenticate_device_flow
                    if [ $? -ne 0 ]; then
                        echo "WARNING: Authentication failed, using existing tokens (server may not work)"
                    fi
                fi
            else
                # Try to refresh anyway (OAuth2 tokens may have expired even if session tokens haven't)
                refresh_tokens || echo "Optional token refresh failed, using existing tokens"
            fi
        else
            echo "No refresh token available, attempting full authentication..."
            authenticate_device_flow
            if [ $? -ne 0 ]; then
                echo "WARNING: Authentication failed, server may not start properly"
            fi
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

# Method C: Token Passthrough (Environment/CLI)
# Support both environment variables and CLI arguments
# Priority: Environment variables > tokens.json > CLI arguments

# Check for session token (environment variable takes precedence)
if [ -n "$HYTALE_SERVER_SESSION_TOKEN" ]; then
    SESSION_TOKEN="$HYTALE_SERVER_SESSION_TOKEN"
    echo "Using session token from HYTALE_SERVER_SESSION_TOKEN environment variable"
elif [ -n "$SERVER_AUTH_ENABLED" ] && [ -f "$TOKEN_FILE" ]; then
    # Get sessionToken from tokens.json (Hytale server EdDSA token)
    SESSION_TOKEN=$(jq -r '.sessionToken // empty' "$TOKEN_FILE" 2>/dev/null)
    if [ -n "$SESSION_TOKEN" ] && [ "$SESSION_TOKEN" != "null" ]; then
        echo "Using session token from $TOKEN_FILE"
    fi
fi

# Check for identity token (environment variable takes precedence)
if [ -n "$HYTALE_SERVER_IDENTITY_TOKEN" ]; then
    IDENTITY_TOKEN="$HYTALE_SERVER_IDENTITY_TOKEN"
    echo "Using identity token from HYTALE_SERVER_IDENTITY_TOKEN environment variable"
elif [ -n "$SERVER_AUTH_ENABLED" ] && [ -f "$TOKEN_FILE" ]; then
    # Get identityToken from tokens.json (Hytale server EdDSA token)
    IDENTITY_TOKEN=$(jq -r '.identityToken // empty' "$TOKEN_FILE" 2>/dev/null)
    if [ -n "$IDENTITY_TOKEN" ] && [ "$IDENTITY_TOKEN" != "null" ]; then
        echo "Using identity token from $TOKEN_FILE"
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
