#!/bin/bash
#===============================================================================
# DEPLOYMENT SCRIPT
#===============================================================================
# Purpose: Deploy Anna's portfolio to a production server
# Usage: ./deploy.sh [server] [environment]
# Example: ./deploy.sh anna-portfolio.com prod
#===============================================================================

set -euo pipefail

# Configuration
REPO_URL="https://github.com/notl0cal/anna-portfolio.git"
SITE_DIR="/var/www/anna-portfolio"
SERVICE_NAME="anna-portfolio"
PORT="${PORT:-8000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

#-------------------------------------------------------------------------------
# PRE-FLIGHT CHECKS
#-------------------------------------------------------------------------------
preflight() {
    log "Running pre-flight checks..."
    
    # Check for required tools
    command -v git >/dev/null 2>&1 || { error "git is required but not installed."; exit 1; }
    command -v curl >/dev/null 2>&1 || { error "curl is required but not installed."; exit 1; }
    
    # Check if running as deploy user
    if [ "$(whoami)" = "root" ]; then
        warn "Running as root. Consider using the 'deploy' user for better security."
    fi
}

#-------------------------------------------------------------------------------
# CLONE OR UPDATE
#-------------------------------------------------------------------------------
deploy_site() {
    local server="${1:-localhost}"
    local env="${2:-dev}"
    
    log "Deploying to $server (environment: $env)"
    
    # Create site directory
    sudo mkdir -p "$SITE_DIR"
    sudo chown -R "$(whoami):$(whoami)" "$SITE_DIR"
    
    # Clone or update repository
    if [ -d "$SITE_DIR/.git" ]; then
        log "Updating existing deployment..."
        cd "$SITE_DIR"
        git pull origin main
    else
        log "Cloning repository..."
        git clone "$REPO_URL" "$SITE_DIR"
        cd "$SITE_DIR"
    fi
    
    # Install dependencies if package.json exists
    if [ -f "package.json" ]; then
        log "Installing npm dependencies..."
        npm ci --production
    fi
    
    # Build if build script exists
    if [ -f "package.json" ] && grep -q '"build"' package.json; then
        log "Building site..."
        npm run build
    fi
    
    log "Site deployed successfully to $SITE_DIR"
}

#-------------------------------------------------------------------------------
# START SERVICE (Simple HTTP Server)
#-------------------------------------------------------------------------------
start_service() {
    log "Starting web service on port $PORT..."
    
    # Stop existing service
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        log "Stopping existing service..."
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    fi
    
    # Create systemd service for Python HTTP server
    cat > /tmp/anna-portfolio.service << EOF
[Unit]
Description=Anna Portfolio Static Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$SITE_DIR
ExecStart=/usr/bin/python3 -m http.server $PORT --bind 127.0.0.1
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/anna-portfolio.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    log "Service started. Status: $(systemctl is-active $SERVICE_NAME)"
}

#-------------------------------------------------------------------------------
# START SERVICE (Node.js with Caddy reverse proxy)
#-------------------------------------------------------------------------------
start_node_service() {
    log "Starting Node.js service..."
    
    # Create systemd service
    cat > /tmp/anna-portfolio-node.service << EOF
[Unit]
Description=Anna Portfolio Node.js Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$SITE_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/anna-portfolio-node.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME-node"
    sudo systemctl start "$SERVICE_NAME-node"
}

#-------------------------------------------------------------------------------
# CONFIGURE CADDY (Reverse Proxy)
#-------------------------------------------------------------------------------
configure_caddy() {
    local domain="${1:-localhost}"
    
    log "Configuring Caddy reverse proxy for $domain..."
    
    # Install Caddy
    sudo apt-get install -y -qq caddy
    
    # Create Caddyfile
    cat > /tmp/Caddyfile << EOF
$domain {
    reverse_proxy 127.0.0.1:$PORT
    tls internal
    log {
        output file /var/log/caddy/anna-portfolio.log
    }
}
EOF
    
    sudo mv /tmp/Caddyfile /etc/caddy/Caddyfile
    sudo systemctl enable caddy
    sudo systemctl restart caddy
    
    log "Caddy configured. Site available at https://$domain"
}

#-------------------------------------------------------------------------------
# VERIFY DEPLOYMENT
#-------------------------------------------------------------------------------
verify() {
    local server="${1:-localhost}"
    local port="${2:-$PORT}"
    
    log "Verifying deployment..."
    
    # Check if server is responding
    if curl -sf "http://$server:$port" > /dev/null 2>&1; then
        log "✓ Server is responding on port $port"
    else
        warn "✗ Server not responding. Check logs with: journalctl -u $SERVICE_NAME"
    fi
    
    # Check SSL if configured
    if command -v openssl >/dev/null 2>&1; then
        if curl -sf "https://$server" > /dev/null 2>&1; then
            log "✓ HTTPS is working"
        fi
    fi
}

#-------------------------------------------------------------------------------
# ROLLBACK
#-------------------------------------------------------------------------------
rollback() {
    log "Rolling back to previous deployment..."
    cd "$SITE_DIR"
    git checkout HEAD~1
    systemctl restart "$SERVICE_NAME"
    log "Rollback complete"
}

#-------------------------------------------------------------------------------
# SHOW STATUS
#-------------------------------------------------------------------------------
status() {
    log "Deployment Status"
    echo "================================"
    echo "Site Directory: $SITE_DIR"
    echo "Port: $PORT"
    echo ""
    echo "Service Status:"
    systemctl is-active "$SERVICE_NAME" 2>/dev/null && echo "  ✓ $SERVICE_NAME is running" || echo "  ✗ $SERVICE_NAME not running"
    
    echo ""
    echo "Recent Commits:"
    cd "$SITE_DIR" && git log --oneline -5 2>/dev/null || echo "  Not a git repository"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    local command="${1:-deploy}"
    local server="${2:-localhost}"
    local env="${3:-dev}"
    
    case "$command" in
        deploy)
            preflight
            deploy_site "$server" "$env"
            start_service
            configure_caddy "$server"
            verify "$server"
            ;;
        start)
            start_service
            configure_caddy "$server"
            ;;
        stop)
            systemctl stop "$SERVICE_NAME"
            ;;
        restart)
            systemctl restart "$SERVICE_NAME"
            ;;
        status)
            status
            ;;
        rollback)
            rollback
            ;;
        verify)
            verify "$server"
            ;;
        help|--help|-h)
            echo "Anna Portfolio Deployment Script"
            echo ""
            echo "Usage: $0 <command> [server] [environment]"
            echo ""
            echo "Commands:"
            echo "  deploy     Full deployment (default)"
            echo "  start      Start the web service"
            echo "  stop       Stop the web service"
            echo "  restart    Restart the web service"
            echo "  status     Show deployment status"
            echo "  rollback   Rollback to previous version"
            echo "  verify     Verify deployment is working"
            echo "  help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 deploy anna-portfolio.com prod"
            echo "  $0 status"
            echo "  $0 rollback"
            ;;
        *)
            error "Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
