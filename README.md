OpenHamClock Appliance Manager v1.1 installation script for Debian Linux.
This helps install OpenHamClock as a service on Debian Linux.
OpenHamClock is available at https://github.com/accius/openhamclock/
This script may work with other Linux distributions.
Modification by N4MCP of the original OpenHamClock Linux install script.
Installs, updates, uninstalls, and manages OpenHamClock as a system service.
Preserves user configuration stored in /opt/openhamclock/.env when requested.

OpenHamClock Installer & Manager Script - Version 1.1

Features:
  - Installs OpenHamClock with systemd service
  - Supports uninstall, reinstall, and update
  - Preserves customized user configuration file (.env)
  - Displays system IP with port 3000 after install
  - Prompts for required dependencies (nodejs, npm, git)
  - Ensures npm has writable HOME for service user
  - Cleans up backups if user chooses to remove everything
  - Shows configuration with "Show configuration" option
