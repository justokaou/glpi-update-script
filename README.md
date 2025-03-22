# GLPI Auto-Upgrade Script

This Bash script automates the process of downloading, extracting, updating, and configuring a specific version of **GLPI** (Gestionnaire Libre de Parc Informatique) on a Debian-based server.

It includes backup of the existing GLPI instance, restoration of important directories, service checks (Apache, MariaDB), and dependency management (PHP, Node.js, gettext, etc.).

## Features

- Downloads a specific GLPI version from GitHub
- Validates the archive before extraction
- Backs up the existing GLPI installation
- Restores `files`, `plugins`, `config`, and `marketplace` directories
- Automatically performs the following actions:
  - Restarts Apache unconditionally
  - Verifies that MariaDB is running, and restarts it only if necessary
  - Installs `nvm` and the latest Node.js LTS if not present
  - Installs PHP dependencies via the GLPI CLI
  - Installs `gettext` if `msgfmt` is missing
- Sets proper permissions
- Prompts to remove the previous version after update

## Requirements

- Debian or Ubuntu server
- Root or sudo privileges
- Apache2 and MariaDB installed
- An existing GLPI installation (recommended) or at least a properly configured Apache + MariaDB environment
- Internet connection (for downloading dependencies and GLPI)

## Installation

1. Clone or download this repository:

```bash
git clone https://github.com/justokaou/glpi-update-script.git
cd glpi-update-script
```

2. Make the script executable:

```bash
chmod +x upgrade_glpi.sh
```

3. Ensure the required packages are installed:

```bash
apt update
apt install -y wget curl tar apache2 mariadb-server php php-cli php-mbstring php-curl php-dom php-mysql php-intl php-xml php-zip php-bz2 php-gd php-imap php-apcu php-cas php-ldap
```

4. Run the script with the desired GLPI version:

```bash
./upgrade_glpi.sh -v <glpi-version>
```

Example:

```bash
./upgrade_glpi.sh -v 10.0.12
```

## Options

- `-v`, `--version` <version> : Required. Specifies the GLPI version to install. Must match an existing release tag on GitHub.
- `-h`, `--help` : Display usage information.

## Notes

**Important**: This script does not include a database backup. It is recommended to create a database dump or a full snapshot before running the upgrade.

- This script does not handle the full initial installation wizard of GLPI (database setup, admin user creation, etc.). It assumes that either:
    - You are upgrading an existing GLPI installation, or
    - You have already prepared the web server and database environment manually.

- The script moves the existing GLPI folder to `/var/www/glpi.old/`.
- After a successful update, you will be prompted to delete the old version.
- If Node.js or `nvm` is not already installed, the script will handle the installation automatically.
- Make sure to run the script as a user with appropriate permissions (typically `root`).

## Disclaimer

This script is provided as-is. Always test on a staging or development environment before running in production.
