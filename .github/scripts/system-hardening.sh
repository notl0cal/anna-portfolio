#!/bin/bash
#===============================================================================
# SYSTEM HARDENING SCRIPT
#===============================================================================
# Purpose: Secure a fresh Linux server for web hosting
# Usage: sudo ./system-hardening.sh [hostname]
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default hostname
HOSTNAME="${1:-anna-portfolio}"

#-------------------------------------------------------------------------------
# 1. UPDATE SYSTEM
#-------------------------------------------------------------------------------
log_info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

#-------------------------------------------------------------------------------
# 2. CONFIGURE HOSTNAME
#-------------------------------------------------------------------------------
log_info "Setting hostname to: $HOSTNAME"
hostnamectl set-hostname "$HOSTNAME"

#-------------------------------------------------------------------------------
# 3. CREATE NON-ROOT USER
#-------------------------------------------------------------------------------
log_info "Creating deployment user..."
if ! id "deploy" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo deploy
    echo "deploy ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/deploy
    chmod 0440 /etc/sudoers.d/deploy
    log_info "User 'deploy' created with sudo privileges"
else
    log_warn "User 'deploy' already exists"
fi

#-------------------------------------------------------------------------------
# 4. CONFIGURE SSH HARDENING
#-------------------------------------------------------------------------------
log_info "Configuring SSH hardening..."
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# SSH Hardening Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
PermitEmptyPasswords yes
Protocol 2
LoginGraceTime 60
EOF

systemctl reload sshd

#-------------------------------------------------------------------------------
# 5. CONFIGURE FIREWALL (UFW)
#-------------------------------------------------------------------------------
log_info "Configuring firewall..."
apt-get install -y -qq ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH only from specific IP (change 0.0.0.0/0 to your IP)
ufw allow ssh comment 'SSH'

# Allow HTTP/HTTPS
ufw allow http comment 'HTTP'
ufw allow https comment 'HTTPS'

# Enable firewall
echo "y" | ufw enable

#-------------------------------------------------------------------------------
# 6. INSTALL FAIL2BAN
#-------------------------------------------------------------------------------
log_info "Installing Fail2Ban..."
apt-get install -y -qq fail2ban

# Configure Fail2Ban for SSH
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

systemctl enable fail2ban
systemctl start fail2ban

#-------------------------------------------------------------------------------
# 7. CONFIGURE AUTOMATIC SECURITY UPDATES
#-------------------------------------------------------------------------------
log_info "Configuring automatic security updates..."
apt-get install -y -qq unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

#-------------------------------------------------------------------------------
# 8. CONFIGURE LOGGING
#-------------------------------------------------------------------------------
log_info "Configuring audit logging..."
apt-get install -y -qq auditd

#-------------------------------------------------------------------------------
# 9. HARDEN KERNEL PARAMETERS
#-------------------------------------------------------------------------------
log_info "Hardening kernel parameters..."
cat >> /etc/sysctl.conf << 'EOF'

# Network hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Kernel hardening
kernel.randomize_va_space = 2
kernel.sysctl = 1
EOF

sysctl -p

#-------------------------------------------------------------------------------
# 10. SET FILE PERMISSIONS
#-------------------------------------------------------------------------------
log_info "Setting secure file permissions..."
chmod 644 /etc/passwd /etc/group
chmod 644 /etc/shadow
chmod 600 /etc/sudoers.d/*
chmod 700 /root

#-------------------------------------------------------------------------------
# SUMMARY
#-------------------------------------------------------------------------------
echo ""
echo "==============================================================================="
log_info "SYSTEM HARDENING COMPLETE"
echo "==============================================================================="
echo ""
echo "Next steps:"
echo "  1. Add your SSH public key to /home/deploy/.ssh/authorized_keys"
echo "  2. Copy your SSH key: ssh-copy-id deploy@<server-ip>"
echo "  3. Test SSH access before disconnecting"
echo "  4. Run the deployment script: ./deploy.sh"
echo ""
echo "Security checks:"
echo "  - SSH root login: DISABLED"
echo "  - Password auth: DISABLED (key-only)"
echo "  - Firewall: UFW enabled (SSH, HTTP, HTTPS)"
echo "  - Fail2Ban: Active"
echo "  - Automatic updates: Enabled"
echo "==============================================================================="
