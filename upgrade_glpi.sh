#!/bin/bash

# Define colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Exit script immediately on any error
set -e

# Help function
usage() {
    echo -e "${CYAN}Usage: $0 [OPTIONS]${NC}"
    echo "Available options:"
    echo "  -h, --help                 Display this help message"
    echo "  -d, --delete-archive       Delete glpi.old after installation"
    echo "  -v, --version <version>    Required. Specifies the GLPI version to install. Must match an existing release tag on GitHub."
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -d|--delete-archive) delete_archive=true ;;
        -v|--version) version="$2"; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
    shift
done

# Variables
glpi_path="/var/www/glpi/"
oldglpi_path="/var/www/glpi.old/"
glpi_tgz=""

# Ensure version is provided
if [ -z "$version" ]; then
    usage
    exit 1
else
    echo -e "${YELLOW}Downloading GLPI version ${version}...${NC}"
    glpi_tgz="/tmp/glpi-${version}.tar.gz"
    wget -q --show-progress -O "$glpi_tgz" "https://github.com/glpi-project/glpi/archive/refs/tags/${version}.tar.gz" || {
        echo -e "${RED}Error: Unable to download the archive. Check the specified version.${NC}"
        exit 1
    }
fi

# Validate the downloaded archive
if ! tar -tzf "$glpi_tgz" >/dev/null; then
    echo -e "${RED}Error: The downloaded archive is corrupted or invalid.${NC}"
    exit 1
fi

echo -e "${CYAN}File $glpi_tgz downloaded successfully. Proceeding with update...${NC}"

# Backup existing GLPI installation
if [ -d "$glpi_path" ]; then
    echo -e "${YELLOW}Backing up the current GLPI installation...${NC}"
    mv "$glpi_path" "$oldglpi_path"
fi

# Extract new version
cd /var/www/
tar -xf "$glpi_tgz"

# Rename extracted folder to the expected path
if [ -d "/var/www/glpi-${version}" ]; then
    mv "/var/www/glpi-${version}" "$glpi_path"
    echo -e "${GREEN}GLPI ${version} extracted and renamed successfully.${NC}"
elif [ -d "$glpi_path" ]; then
    echo -e "${YELLOW}Directory ${glpi_path} already exists.${NC}"
else
    echo -e "${RED}Error: No GLPI directory found after extraction.${NC}"
    exit 1
fi

# Restore essential folders from the previous installation
echo -e "${CYAN}Restoring essential directories from previous installation...${NC}"

for dir in "files" "plugins" "config" "marketplace"; do
    if [ -d "${oldglpi_path}$dir" ]; then
        cp -Rf "${oldglpi_path}$dir" "$glpi_path"
        echo -e "${GREEN}Successfully restored $dir.${NC}"
    else
        echo -e "${RED}Warning: $dir does not exist in the previous installation.${NC}"
    fi
done

# Set appropriate permissions
chown -R www-data:www-data "$glpi_path"
chmod -R 755 "$glpi_path"

# Restart Apache service
echo -e "${YELLOW}Restarting apache2 service...${NC}"
systemctl restart apache2

if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}Apache restarted successfully.${NC}"
else
    echo -e "${RED}Error: Apache is not running. Check logs for details.${NC}"
fi

# Check if MariaDB is running; restart if necessary
if systemctl is-active --quiet mariadb; then
    echo -e "${GREEN}MariaDB is active.${NC}"
else
    echo -e "${RED}MariaDB is inactive. Attempting to restart...${NC}"
    systemctl restart mariadb
    if systemctl is-active --quiet mariadb; then
        echo -e "${GREEN}MariaDB restarted successfully.${NC}"
    else
        echo -e "${RED}Error: MariaDB is not running. Check logs for details.${NC}"
    fi
fi

# Check if msgfmt is installed; install if missing
if ! command -v msgfmt >/dev/null 2>&1; then
    echo -e "${RED}msgfmt not found. Installing...${NC}"
    apt-get update -qq
    apt-get install -y -qq gettext
    echo -e "${GREEN}msgfmt installed...${NC}"
else
    echo -e "${GREEN}msgfmt is already installed.${NC}"
fi

# Set NVM_DIR and load nvm manually
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
else
    echo -e "${RED}nvm not found. Installing...${NC}"
    apt install -y -qq build-essential libssl-dev
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    echo -e "${GREEN}nvm is now installed...${NC}"
fi

# Compare current Node.js version with the latest LTS available via nvm
last_node_lts=$(nvm ls-remote --lts | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -n 1 | sed 's/v//')

# Check if Node.js is already installed
if command -v node >/dev/null 2>&1; then
    current_node=$(node -v | sed 's/v//')
    echo -e "${YELLOW}Current installed Node.js version: $current_node${NC}"
else
    current_node=""
    echo -e "${YELLOW}Node.js is not currently installed.${NC}"
fi

echo -e "${YELLOW}Latest available Node.js LTS: $last_node_lts${NC}"

# Update Node.js if a newer LTS version is available
if [ -z "$current_node" ] || [ "$(printf "%s\n%s" "$last_node_lts" "$current_node" | sort -V | head -n 1)" != "$last_node_lts" ]; then
    echo -e "${CYAN}Installing or updating Node.js to the latest LTS version...${NC}"
    nvm install --lts
    nvm use --lts
    nvm alias default lts
    echo -e "${GREEN}Node.js $(node -v) installed successfully.${NC}"
else
    echo -e "${GREEN}Node.js is already up to date.${NC}"
fi

# Install unzip for PHP dependencies
echo -e "${CYAN}Check unzip for PHP dependencies...${NC}"
if ! command -v unzip >/dev/null 2>&1; then
    echo -e "${RED}unzip not found. Installing...${NC}"
    apt-get update -qq
    apt-get install -y -qq unzip
    echo -e "${GREEN}Unzip installed successfully.${NC}"
else
    echo -e "${GREEN}unzip is already installed.${NC}"
fi

# Install PHP dependencies and compile translations
echo -e "${YELLOW}Installing PHP dependencies and compiling translations...${NC}"
export COMPOSER_ALLOW_SUPERUSER=1
php /var/www/glpi/bin/console dependencies install --no-interaction > /var/log/glpi_composer.log 2>&1
php /var/www/glpi/bin/console locales:compile --no-interaction > /var/log/glpi_locales.log 2>&1
echo -e "${CYAN}Logs have been saved to /var/log/glpi_*.log${NC}"

# Final verification
if php /var/www/glpi/bin/console --version >/dev/null 2>&1; then
    echo -e "${GREEN}GLPI installation is complete and ready.${NC}"
else
    echo -e "${RED}GLPI encountered an issue. Please review the error output.${NC}"
    exit 1
fi

# Handle deletion of the old GLPI installation
if [ "$delete_archive" = true ]; then
    rm -rf "$oldglpi_path"
    echo -e "${GREEN}Previous installation removed (auto-deletion enabled).${NC}"
else
    echo -e "${YELLOW}Do you want to remove the previous GLPI installation (${oldglpi_path})? (y/n): ${NC}"
    read -r delete_old
    if [[ "$delete_old" =~ ^[yYoO]$ ]]; then
        rm -rf "$oldglpi_path"
        echo -e "${GREEN}Previous installation removed.${NC}"
    else
        echo -e "${CYAN}Previous installation retained.${NC}"
    fi
fi

echo -e "${GREEN}GLPI update completed successfully.${NC}"
