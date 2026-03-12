#!/bin/bash
#
# OpenHamClock Appliance Manager v1.1 installation script for Debian Linux.
# This script may work with other Linux distributions.
# Modification by N4MCP of the original OpenHamClock Linux install script.
# Installs, updates, uninstalls, and manages OpenHamClock as a system service.
# Preserves user configuration stored in /opt/openhamclock/.env when requested.
#
# OpenHamClock Installer & Manager Script - Version 1.1
#
# Features:
#   - Installs OpenHamClock with systemd service
#   - Supports uninstall, reinstall, and update
#   - Preserves customized user configuration file (.env)
#   - Displays system IP with port 3000 after install
#   - Prompts for required dependencies (nodejs, npm, git)
#   - Ensures npm has writable HOME for service user
#   - Cleans up backups if user chooses to remove everything
#   - Shows configuration with "Show configuration" option
#

set -e

SERVICE_USER="openhamclock"
INSTALL_DIR="/opt/openhamclock"
BACKUP_DIR="/opt/openhamclock_backup"
ENV_FILE="$INSTALL_DIR/.env"
ENV_BACKUP="$BACKUP_DIR/.env"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Colors helper
echo_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Detect IP address
get_ip() {
    hostname -I | awk '{print $1}'
}

# Check required commands
check_dependency() {
    local cmd=$1
    local install_cmd=$2
    if ! command -v "$cmd" &>/dev/null; then
        echo_color "$YELLOW" "$cmd not found."
        read -rp "Install $cmd? [Y/n]: " response
        response=${response,,}
        if [[ "$response" == "y" || "$response" == "" ]]; then
            eval "$install_cmd"
        else
            echo_color "$RED" "$cmd is required. Exiting."
            exit 1
        fi
    else
        echo_color "$GREEN" "✓ $cmd detected"
    fi
}

# Ensure service user exists
ensure_service_user() {
    if ! id -u "$SERVICE_USER" &>/dev/null; then
        echo "Creating system user $SERVICE_USER..."
        useradd -r -s /usr/sbin/nologin "$SERVICE_USER"
    fi
}

# Backup user configuration if modified
backup_env() {
    if [[ -f "$ENV_FILE" ]]; then
        mkdir -p "$BACKUP_DIR"
        if [[ -f "$ENV_BACKUP" ]]; then
            if ! cmp -s "$ENV_FILE" "$ENV_BACKUP"; then
                echo_color "$YELLOW" "Existing backup differs from current configuration."
                read -rp "Overwrite backup user configuration file? [y/N]: " choice
                choice=${choice,,}
                if [[ "$choice" == "y" ]]; then
                    cp "$ENV_FILE" "$ENV_BACKUP"
                    echo_color "$GREEN" "Backup overwritten."
                else
                    echo_color "$BLUE" "Backup kept. Changes in .env file will not be saved."
                fi
            else
                echo_color "$BLUE" "Configuration unchanged. Backup skipped."
            fi
        else
            cp "$ENV_FILE" "$ENV_BACKUP"
            echo_color "$GREEN" "Configuration backed up to $ENV_BACKUP"
        fi
    fi
}

# Restore user configuration if requested
restore_env() {
    if [[ -f "$ENV_BACKUP" ]]; then
        echo_color "$BLUE" "Backup user configuration file exists: $ENV_BACKUP"
        echo "  1) Restore the backup user configuration file"
        echo "  2) Remove the backup user configuration file and start fresh"
        echo "  3) Leave the backup user configuration file as-is and continue with a fresh installation"
        read -rp "Selection [1-3]: " sel
        case $sel in
            1)
                mkdir -p "$INSTALL_DIR"
                cp "$ENV_BACKUP" "$ENV_FILE"
                echo_color "$GREEN" "Backup restored."
                ;;
            2)
                rm -f "$ENV_BACKUP"
                echo_color "$YELLOW" "Backup removed. Fresh installation will proceed."
                ;;
            3)
                echo_color "$BLUE" "Backup left as-is. Continuing installation..."
                ;;
            *)
                echo_color "$RED" "Invalid selection. Exiting."
                exit 1
                ;;
        esac
    fi
}

# Install Node.js dependencies and build
install_dependencies_and_build() {
    echo_color "$BLUE" "Installing Node.js dependencies and building..."
    sudo -u "$SERVICE_USER" bash -c "export HOME=$INSTALL_DIR; cd $INSTALL_DIR; npm install; npm run build"
}

# Install OpenHamClock
install_ohc() {
    restore_env
    if [[ -d "$INSTALL_DIR" && ! -z "$(ls -A $INSTALL_DIR)" ]]; then
        echo_color "$RED" "Installation directory $INSTALL_DIR exists and is not empty."
        echo "Please remove or move it before proceeding."
        exit 1
    fi

    git clone https://github.com/accius/openhamclock.git "$INSTALL_DIR"
    chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"

    install_dependencies_and_build

    # Create systemd service
    cat >/etc/systemd/system/openhamclock.service <<EOF
[Unit]
Description=OpenHamClock Server
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/npm start
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable openhamclock.service
    systemctl start openhamclock.service

    echo_color "$GREEN" "OpenHamClock installation complete."
    echo ""
    echo_color "$BLUE" "Access the interface at: http://$(get_ip):3000"
}

# Uninstall OpenHamClock
uninstall_ohc() {
    read -rp "Are you sure you want to remove OpenHamClock completely? [y/N]: " confirm
    confirm=${confirm,,}
    if [[ "$confirm" != "y" ]]; then
        echo_color "$BLUE" "Uninstall cancelled."
        return
    fi

    systemctl stop openhamclock.service 2>/dev/null || true
    systemctl disable openhamclock.service 2>/dev/null || true
    rm -f /etc/systemd/system/openhamclock.service
    systemctl daemon-reload

    read -rp "Keep current configuration file ($ENV_FILE)? [y/N]: " keep_conf
    keep_conf=${keep_conf,,}
    if [[ "$keep_conf" == "y" && -f "$ENV_FILE" ]]; then
        backup_env
    fi

    rm -rf "$INSTALL_DIR"
    echo_color "$GREEN" "OpenHamClock removed."
}

# Show configuration
show_config() {
    if [[ -f "$ENV_FILE" ]]; then
        echo_color "$BLUE" "Current user configuration file ($ENV_FILE):"
        cat "$ENV_FILE"
    else
        echo_color "$YELLOW" "No configuration file found."
    fi
}

# Main menu
main_menu() {
    echo ""
    echo "OpenHamClock Manager"
    echo ""
    echo "Choose an action:"
    echo "  1) Uninstall OpenHamClock"
    echo "  2) Reinstall (uninstall + install)"
    echo "  3) Update only"
    echo "  4) Show configuration"
    echo "  5) Exit"
    read -rp "Selection [1-5]: " choice

    case $choice in
        1) uninstall_ohc ;;
        2) uninstall_ohc; install_ohc ;;
        3) install_ohc ;;
        4) show_config ;;
        5) exit 0 ;;
        *) echo_color "$RED" "Invalid choice."; main_menu ;;
    esac
}

# Entry point
ensure_service_user
check_dependency node "curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && sudo apt-get install -y nodejs"
check_dependency npm "sudo apt-get install -y npm"
check_dependency git "sudo apt-get install -y git"

if [[ ! -d "$INSTALL_DIR" || -z "$(ls -A $INSTALL_DIR)" ]]; then
    read -rp "OpenHamClock is not installed. Install OpenHamClock now? [Y/n]: " resp
    resp=${resp,,}
    if [[ "$resp" == "y" || "$resp" == "" ]]; then
        install_ohc
    else
        echo_color "$BLUE" "Installation skipped."
        exit 0
    fi
else
    main_menu
fi
