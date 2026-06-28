#!/bin/bash

# Directories
VERSION_FILE="${VERSION_FILE:-/hytale/VERSION}"
APP_DIR="${APP_DIR:-/hytale}"

# Configuration defaults
SERVER_AUTH_ENABLED="${SERVER_AUTH_ENABLED:-true}"
SERVER_ASSETS_ZIP="${SERVER_ASSETS_ZIP:-}"
SERVER_BACKUP_DIR="${SERVER_BACKUP_DIR:-/hytale/backups}"
SERVER_BACKUP_INTERVAL="${SERVER_BACKUP_INTERVAL:-10}"
# Align with https://maven.hytale.com/pre-release (same channel as mod development against Server API)
DOWNLOADER_PATCHLINE="${DOWNLOADER_PATCHLINE:-pre-release}"
# Prefer DOWNLOADER_SKIP_UPDATE_CHECK; SEVER_SKIP_UPDATE_CHECK is a legacy typo alias
DOWNLOADER_SKIP_UPDATE_CHECK="${DOWNLOADER_SKIP_UPDATE_CHECK:-${SEVER_SKIP_UPDATE_CHECK:-false}}"
JAVA_DEBUG="${JAVA_DEBUG:-false}"