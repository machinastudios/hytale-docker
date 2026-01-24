#!/bin/bash

# Set the log level to INFO by default
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Color codes
COLOR_ERROR="\033[1;31m"    # Bold Red
COLOR_WARNING="\033[1;33m"  # Bold Yellow
COLOR_INFO="\033[1;36m"     # Bold Cyan
COLOR_DEBUG="\033[1;37m"    # Bold White
COLOR_RESET="\033[0m"

# Map the log levels to integers
declare -A LOG_LEVEL_TO_INT=(
    ["ERROR"]=1
    ["WARNING"]=2
    ["INFO"]=3
    ["DEBUG"]=4
)

# Get the log level integer
LOG_LEVEL_INT=${LOG_LEVEL_TO_INT[$LOG_LEVEL]}

# Can log function
function can_log() {
    local message_level_int=${LOG_LEVEL_TO_INT[$1]}
    [[ $message_level_int -le $LOG_LEVEL_INT ]]
}

# Logger function with color
function log_message() {
    local level="$1"
    shift
    local message="$*"

    case "$level" in
        "ERROR")
            local color="$COLOR_ERROR"
            ;;
        "WARNING")
            local color="$COLOR_WARNING"
            ;;
        "INFO")
            local color="$COLOR_INFO"
            ;;
        "DEBUG")
            local color="$COLOR_DEBUG"
            ;;
        *)
            local color="$COLOR_RESET"
            ;;
    esac

    echo -e "${color} $(date +'%Y-%m-%d %H:%M:%S') [$level] $message${COLOR_RESET}"
}

# Error function
function log_error() {
    if can_log "ERROR"; then
        log_message "ERROR" "$@"
    fi
}

# Warning function
function log_warning() {
    if can_log "WARNING"; then
        log_message "WARNING" "$@"
    fi
}

# Info function
function log_info() {
    if can_log "INFO"; then
        log_message "INFO" "$@"
    fi
}

# Debug function
function log_debug() {
    if can_log "DEBUG"; then
        log_message "DEBUG" "$@"
    fi
}