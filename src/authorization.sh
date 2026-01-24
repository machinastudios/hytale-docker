#!/bin/bash

# Import scripts
source /src/logger.sh
source /src/variables.sh

# Device Code Flow (RFC 8628) Authentication
# Token storage location (single file with all tokens)
TOKEN_FILE="$APP_DIR/tokens.json"
DOWNLOADER_CREDENTIALS_PATH="$APP_DIR/.hytale-downloader-credentials.json"

# OAuth2 endpoints
CLIENT_ID="hytale-server"
DEVICE_AUTH_URL="https://oauth.accounts.hytale.com/oauth2/device/auth"
TOKEN_URL="https://oauth.accounts.hytale.com/oauth2/token"
SCOPE="openid offline auth:server"
PROFILES_URL="https://account-data.hytale.com/my-account/get-profiles"
SESSION_URL="https://sessions.hytale.com/game-session/new"

# Function to perform Device Code Flow authentication
function authenticate_device_flow() {
    echo "==================================================================="
    echo "DEVICE CODE FLOW AUTHENTICATION"
    echo "==================================================================="
    
    # Request device code
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
        log_error "Failed to obtain device code. Response: $AUTH_RESPONSE"
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
            log_error "Authorization failed: $ERROR"
            log_error "Response: $TOKEN_RESPONSE"
            return 1
        else
            # Success - extract tokens
            ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
            ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token // empty')
            REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')
            
            if [ -z "$ACCESS_TOKEN" ]; then
                log_error "Failed to obtain access token. Response: $TOKEN_RESPONSE"
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
                log_warning "Could not get profile UUID. Response: $PROFILES_RESPONSE"
                log_warning "You may need to set HYTALE_SERVER_OWNER_UUID environment variable"
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
                log_error "Failed to get sessionToken and identityToken. Response: $SESSION_RESPONSE"
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
    
    log_error "Authorization timed out after $EXPIRES_IN seconds"
    return 1
}

# Function to refresh tokens using refresh token
function refresh_tokens() {
    if [ ! -f "$TOKEN_FILE" ]; then
        return 1
    fi
    
    REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$TOKEN_FILE")
    PROFILE_UUID=$(jq -r '.profile_uuid // empty' "$TOKEN_FILE")
    
    if [ -z "$REFRESH_TOKEN" ]; then
        return 1
    fi
    
    log_info "Refreshing OAuth2 tokens..."
    TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$CLIENT_ID" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$REFRESH_TOKEN")
    
    ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')
    
    if [ -n "$ERROR" ] && [ "$ERROR" != "null" ]; then
        log_error "Token refresh failed: $ERROR"
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
        log_info "Getting available profiles..."
        PROFILES_RESPONSE=$(curl -s -X GET "$PROFILES_URL" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        PROFILE_UUID=$(echo "$PROFILES_RESPONSE" | jq -r '.profiles[0].uuid // .owner // empty')
    fi
    
    if [ -z "$PROFILE_UUID" ] || [ "$PROFILE_UUID" = "null" ]; then
        log_warning "Could not get profile UUID, tokens may not work"
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
    log_info "Creating new game session..."
    SESSION_RESPONSE=$(curl -s -X POST "$SESSION_URL" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"uuid\":\"$PROFILE_UUID\"}")
    
    # Extract sessionToken and identityToken (EdDSA tokens)
    SESSION_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.sessionToken // empty')
    IDENTITY_TOKEN=$(echo "$SESSION_RESPONSE" | jq -r '.identityToken // empty')
    EXPIRES_AT=$(echo "$SESSION_RESPONSE" | jq -r '.expiresAt // empty')
    
    if [ -z "$SESSION_TOKEN" ] || [ -z "$IDENTITY_TOKEN" ]; then
        log_warning "Failed to get new session tokens, using OAuth2 tokens only"
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
    
    log_info "Tokens refreshed successfully"
    generate_downloader_credentials
    return 0
}

# Function to generate the Hytale downloader credentials
# using the TOKEN_FILE
# Format is:
# {
#     "access_token": "your_access_token",
#     "refresh_token": "your_refresh_token",
#     "expires_at": "your_expires_at_integer",
#     "branch": "release",
# }
function generate_downloader_credentials() {
    if [ -f "$TOKEN_FILE" ]; then
        ACCESS_TOKEN=$(jq -r '.access_token // empty' "$TOKEN_FILE")
        REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$TOKEN_FILE")
        EXPIRES_AT=$(date -u -d "$EXPIRES_AT" +%s 2>/dev/null || echo "0")
        BRANCH="${DOWNLOADER_PATCHLINE:-release}"

        echo "{\"access_token\":\"$ACCESS_TOKEN\",\"refresh_token\":\"$REFRESH_TOKEN\",\"expires_at\":$EXPIRES_AT,\"branch\":\"$BRANCH\"}" > "$DOWNLOADER_CREDENTIALS_PATH"

        log_info "Downloader credentials generated successfully"
        log_debug "Downloader credentials: $DOWNLOADER_CREDENTIALS_PATH"
    else
        log_error "Failed to generate downloader credentials. TOKEN_FILE not found"
        return 1
    fi

    log_info "Downloader credentials generated successfully"

    return 0
}

# Function to check if authentication is needed
# Also generates the Hytale downloader credentials
function authorization_check() {
    # If server auth is disabled, return 0
    if [ -z "$SERVER_AUTH_ENABLED" ]; then
        return 0
    fi

    # If there's no token file, authenticate
    if [ ! -f "$TOKEN_FILE" ]; then
        log_info "Authentication required..."

        authenticate_device_flow

        if [ $? -ne 0 ]; then
            log_warning "Authentication failed. Server may not start properly."
            log_info "You can disable authentication by removing SERVER_AUTH_ENABLED or"
            log_info "manually authenticate using: /auth login device"
        fi

        return 0
    fi

    log_debug "Checking token validity..."

    # Check if token is expired
    EXPIRES_AT=$(jq -r '.expires_at // empty' "$TOKEN_FILE" 2>/dev/null)
    SESSION_TOKEN=$(jq -r '.sessionToken // empty' "$TOKEN_FILE" 2>/dev/null)
    
    # By default, we don't need to refresh
    NEED_REFRESH=false
    
    # If expires_at is available
    if [ -n "$EXPIRES_AT" ] && [ "$EXPIRES_AT" != "null" ] && [ "$EXPIRES_AT" != "" ]; then
        # Check if expires_at is in the past (format: 2026-01-07T15:00:00Z)
        CURRENT_TIMESTAMP=$(date -u +%s)
        EXPIRES_TIMESTAMP=$(date -u -d "$EXPIRES_AT" +%s 2>/dev/null || echo "0")
        
        if [ "$EXPIRES_TIMESTAMP" -gt 0 ] && [ "$CURRENT_TIMESTAMP" -ge "$EXPIRES_TIMESTAMP" ]; then
            log_warning "Token expired at $EXPIRES_AT, refreshing..."
            NEED_REFRESH=true
        fi
    elif [ -z "$SESSION_TOKEN" ] || [ "$SESSION_TOKEN" = "null" ] || [ "$SESSION_TOKEN" = "" ]; then
        # No session token, need to refresh
        log_warning "No valid session token found, refreshing..."
        NEED_REFRESH=true
    fi
    
    # Get the refresh token from the token file
    REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$TOKEN_FILE" 2>/dev/null)

    # If no refresh token is available, attempt full authentication
    if [ -z "$REFRESH_TOKEN" ] || [ "$REFRESH_TOKEN" = "null" ]; then
        log_info "No refresh token available, attempting full authentication..."
        authenticate_device_flow
        return 0
    fi

    # If a refresh is needed
    if [ "$NEED_REFRESH" = true ]; then
        log_info "A refresh is needed, attempting to refresh tokens..."

        # Try to refresh tokens
        if refresh_tokens; then
            log_info "Tokens refreshed successfully"
            generate_downloader_credentials
        else
            log_info "Token refresh failed, attempting full authentication..."

            authenticate_device_flow

            if [ $? -ne 0 ]; then
                log_warning "Authentication failed, using existing tokens (server may not work)"
            fi
        fi

        return 0
    fi

    log_info "No refresh is needed, using existing tokens"

    return 0
}