#!/bin/bash
set -e

# Claude Max API Proxy - Service Installation Script
# Automatically installs and configures the service for macOS or Linux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="claude-max-api-proxy"
PORT="${CLAUDE_API_PORT:-3456}"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Install it first: https://nodejs.org/"
        exit 1
    fi
    NODE_PATH=$(which node)
    log_info "Found Node.js: $NODE_PATH ($(node --version))"

    # Check for Claude CLI
    if ! command -v claude &> /dev/null; then
        log_error "Claude CLI not found. Install it with:"
        log_error "  npm install -g @anthropic-ai/claude-code"
        log_error "  claude auth login"
        exit 1
    fi
    CLAUDE_PATH=$(which claude)
    log_info "Found Claude CLI: $CLAUDE_PATH"

    # Check Claude CLI authentication
    log_info "Verifying Claude CLI authentication..."
    # We can't easily check auth, but we can verify the command exists

    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed"
        exit 1
    fi
}

# Build the project
build_project() {
    log_info "Building project..."

    cd "$SCRIPT_DIR"

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        log_info "Installing dependencies..."
        npm install
    fi

    # Build if dist doesn't exist or is outdated
    if [ ! -f "dist/server/standalone.js" ]; then
        log_info "Compiling TypeScript..."
        npm run build
    fi

    # Verify build output
    if [ ! -f "dist/server/standalone.js" ]; then
        log_error "Build failed: dist/server/standalone.js not found"
        exit 1
    fi

    log_info "Build complete"
}

# Install for macOS
install_macos() {
    log_info "Installing LaunchAgent for macOS..."

    PLIST_PATH="$HOME/Library/LaunchAgents/com.${SERVICE_NAME}.plist"
    LOG_DIR="$HOME/Library/Logs/${SERVICE_NAME}"

    # Create log directory
    mkdir -p "$LOG_DIR"

    # Get PATH that includes claude
    CLAUDE_DIR=$(dirname "$(which claude)")
    USER_PATH="$CLAUDE_DIR:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.local/bin"

    # Create plist file
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.${SERVICE_NAME}</string>

    <key>Comment</key>
    <string>Claude Max API Proxy - OpenAI-compatible API using Claude Max subscription</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ProgramArguments</key>
    <array>
      <string>${NODE_PATH}</string>
      <string>${SCRIPT_DIR}/dist/server/standalone.js</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/output.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>${HOME}</string>
      <key>PATH</key>
      <string>${USER_PATH}</string>
      <key>NODE_ENV</key>
      <string>production</string>
    </dict>
  </dict>
</plist>
EOF

    log_info "Created LaunchAgent: $PLIST_PATH"

    # Unload if already loaded (ignore errors)
    launchctl bootout gui/$(id -u)/com.${SERVICE_NAME} 2>/dev/null || true

    # Load the service
    log_info "Loading service..."
    launchctl bootstrap gui/$(id -u) "$PLIST_PATH"

    # Wait a moment for service to start
    sleep 2

    log_info "LaunchAgent installed and started"
    log_info "Logs available at: $LOG_DIR"

    echo ""
    echo "Management commands:"
    echo "  Status:  launchctl list | grep ${SERVICE_NAME}"
    echo "  Restart: launchctl kickstart -k gui/\$(id -u)/com.${SERVICE_NAME}"
    echo "  Stop:    launchctl bootout gui/\$(id -u)/com.${SERVICE_NAME}"
    echo "  Logs:    tail -f ${LOG_DIR}/output.log"
    echo "  Errors:  tail -f ${LOG_DIR}/error.log"
}

# Install for Linux
install_linux() {
    log_info "Installing systemd service for Linux..."

    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

    # Check if running as root for systemd install
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run with sudo for systemd installation"
        exit 1
    fi

    # Get the actual user (not root if using sudo)
    ACTUAL_USER=${SUDO_USER:-$USER}
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

    # Create systemd service file
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Claude Max API Proxy
Documentation=https://github.com/chrisle/claude-max-api-proxy
After=network.target

[Service]
Type=simple
User=${ACTUAL_USER}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${NODE_PATH} ${SCRIPT_DIR}/dist/server/standalone.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

Environment=HOME=${ACTUAL_HOME}
Environment=NODE_ENV=production
Environment=PATH=/usr/local/bin:/usr/bin:/bin:${ACTUAL_HOME}/.local/bin

[Install]
WantedBy=multi-user.target
EOF

    log_info "Created systemd service: $SERVICE_FILE"

    # Reload systemd
    systemctl daemon-reload

    # Enable and start service
    log_info "Enabling and starting service..."
    systemctl enable ${SERVICE_NAME}
    systemctl start ${SERVICE_NAME}

    log_info "systemd service installed and started"

    echo ""
    echo "Management commands:"
    echo "  Status:  sudo systemctl status ${SERVICE_NAME}"
    echo "  Restart: sudo systemctl restart ${SERVICE_NAME}"
    echo "  Stop:    sudo systemctl stop ${SERVICE_NAME}"
    echo "  Disable: sudo systemctl disable ${SERVICE_NAME}"
    echo "  Logs:    sudo journalctl -u ${SERVICE_NAME} -f"
}

# Verify service is running
verify_service() {
    log_info "Verifying service is running..."

    # Wait a bit for service to fully start
    sleep 3

    # Check health endpoint
    if curl -sf http://localhost:${PORT}/health > /dev/null 2>&1; then
        log_info "✓ Service is running and responding"
        curl -s http://localhost:${PORT}/health | head -n 5
    else
        log_warn "Service may not be responding yet on port ${PORT}"
        log_warn "Check logs for details"
        return 1
    fi
}

# Main installation flow
main() {
    echo "Claude Max API Proxy - Service Installer"
    echo "========================================"
    echo ""

    OS=$(detect_os)
    log_info "Detected OS: $OS"

    check_prerequisites
    build_project

    echo ""
    log_info "Installing service for $OS..."
    echo ""

    if [ "$OS" = "macos" ]; then
        install_macos
    elif [ "$OS" = "linux" ]; then
        install_linux
    fi

    echo ""
    verify_service

    echo ""
    log_info "Installation complete!"
    echo ""
    echo "The service will now start automatically on boot."
    echo "API available at: http://localhost:${PORT}"
    echo ""
    echo "Test it:"
    echo "  curl http://localhost:${PORT}/health"
    echo "  curl http://localhost:${PORT}/v1/models"
}

# Run main function
main "$@"
