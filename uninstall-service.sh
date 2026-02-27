#!/bin/bash
set -e

# Claude Max API Proxy - Service Uninstallation Script

SERVICE_NAME="claude-max-api-proxy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        log_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
}

# Uninstall for macOS
uninstall_macos() {
    log_info "Uninstalling LaunchAgent for macOS..."

    PLIST_PATH="$HOME/Library/LaunchAgents/com.${SERVICE_NAME}.plist"

    # Check if service exists
    if [ ! -f "$PLIST_PATH" ]; then
        log_warn "Service not found at: $PLIST_PATH"
        return 0
    fi

    # Stop and unload the service
    log_info "Stopping service..."
    launchctl bootout gui/$(id -u)/com.${SERVICE_NAME} 2>/dev/null || log_warn "Service was not running"

    # Remove plist file
    log_info "Removing LaunchAgent configuration..."
    rm -f "$PLIST_PATH"

    log_info "LaunchAgent uninstalled"

    # Ask about logs
    LOG_DIR="$HOME/Library/Logs/${SERVICE_NAME}"
    if [ -d "$LOG_DIR" ]; then
        echo ""
        read -p "Remove log files at $LOG_DIR? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$LOG_DIR"
            log_info "Logs removed"
        fi
    fi
}

# Uninstall for Linux
uninstall_linux() {
    log_info "Uninstalling systemd service for Linux..."

    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run with sudo for systemd uninstallation"
        exit 1
    fi

    # Check if service exists
    if [ ! -f "$SERVICE_FILE" ]; then
        log_warn "Service not found at: $SERVICE_FILE"
        return 0
    fi

    # Stop and disable service
    log_info "Stopping and disabling service..."
    systemctl stop ${SERVICE_NAME} 2>/dev/null || log_warn "Service was not running"
    systemctl disable ${SERVICE_NAME} 2>/dev/null || true

    # Remove service file
    log_info "Removing systemd service file..."
    rm -f "$SERVICE_FILE"

    # Reload systemd
    systemctl daemon-reload

    log_info "systemd service uninstalled"
}

# Main uninstallation flow
main() {
    echo "Claude Max API Proxy - Service Uninstaller"
    echo "==========================================="
    echo ""

    OS=$(detect_os)
    log_info "Detected OS: $OS"

    echo ""
    read -p "Are you sure you want to uninstall the service? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    echo ""
    if [ "$OS" = "macos" ]; then
        uninstall_macos
    elif [ "$OS" = "linux" ]; then
        uninstall_linux
    fi

    echo ""
    log_info "Uninstallation complete!"
    echo ""
    echo "Note: The project files have not been removed."
    echo "To completely remove, delete the project directory manually."
}

# Run main function
main "$@"
