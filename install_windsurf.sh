#!/bin/bash
#
# Universal Windsurf Installation Script
# This script installs Windsurf on various Linux distributions
# Supported package managers: apt, dnf/yum, zypper, pacman

set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
WINDSURF_GPG_KEY_URL="https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg"
WINDSURF_REPO_URL="https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt"
APP_NAME="windsurf"

# Check if running as root or with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Function to detect the OS
detect_os() {
    # Try to get OS info from os-release file
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        OS_LIKE=$ID_LIKE
    elif [ -f /usr/lib/os-release ]; then
        . /usr/lib/os-release
        OS=$ID
        VERSION=$VERSION_ID
        OS_LIKE=$ID_LIKE
    else
        echo -e "${RED}Cannot detect OS. Exiting.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Detected OS: $OS $VERSION${NC}"
}

# Function to launch the Windsurf GUI application
launch_windsurf() {
    echo -e "${BLUE}Attempting to launch Windsurf...${NC}"
    
    # Get the current user who is running sudo
    ACTUAL_USER=""
    if [ -n "$SUDO_USER" ]; then
        ACTUAL_USER="$SUDO_USER"
    elif [ -n "$LOGNAME" ]; then
        ACTUAL_USER="$LOGNAME"
    fi
    
    if [ -z "$ACTUAL_USER" ]; then
        ACTUAL_USER=$(whoami)
        if [ "$ACTUAL_USER" = "root" ]; then
            # Try to find a non-root user
            ACTUAL_USER=$(who | grep -v root | head -n 1 | awk '{print $1}')
            if [ -z "$ACTUAL_USER" ]; then
                # Default back to the sudo user if we can't find anyone else
                ACTUAL_USER="$SUDO_USER"
            fi
        fi
    fi
    
    # Try multiple approaches to launch Windsurf
    
    # Approach 1: Use the .desktop file if available
    if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
        # Find desktop file
        DESKTOP_FILE=$(find /usr/share/applications ~/.local/share/applications -name "*windsurf*.desktop" 2>/dev/null | head -n 1)
        
        if [ -n "$DESKTOP_FILE" ]; then
            # Extract the Exec line from the .desktop file
            EXEC_CMD=$(grep "^Exec=" "$DESKTOP_FILE" | head -n 1 | sed 's/^Exec=//' | sed 's/%[a-zA-Z]//')
            if [ -n "$EXEC_CMD" ]; then
                echo -e "${GREEN}Launching Windsurf using desktop file...${NC}"
                # Launch as the actual user with DISPLAY environment
                su - "$ACTUAL_USER" -c "export DISPLAY=:0; nohup $EXEC_CMD >/dev/null 2>&1 &"
                sleep 1
                echo -e "${GREEN}Launch command sent. Windsurf should start momentarily.${NC}"
                return 0
            fi
        fi
    fi
    
    # Approach 2: Direct command
    if command -v windsurf >/dev/null 2>&1; then
        echo -e "${GREEN}Launching Windsurf directly...${NC}"
        
        # Try to launch for non-root user
        if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
            # Try various DISPLAY settings
            su - "$ACTUAL_USER" -c "export DISPLAY=:0; nohup windsurf >/dev/null 2>&1 &"
            sleep 1
            
            # Also try with Wayland support
            su - "$ACTUAL_USER" -c "export DISPLAY=:0; export WAYLAND_DISPLAY=wayland-0; nohup windsurf >/dev/null 2>&1 &"
            sleep 1
            
            # For systems where the first user's display might be :1
            su - "$ACTUAL_USER" -c "export DISPLAY=:1; nohup windsurf >/dev/null 2>&1 &"
            sleep 1
        else
            # If we couldn't determine a non-root user, try with root
            export DISPLAY=:0
            nohup windsurf >/dev/null 2>&1 &
            sleep 1
        fi
        
        echo -e "${GREEN}Launch command sent. Windsurf should start momentarily if a display is available.${NC}"
        echo -e "${YELLOW}If Windsurf doesn't appear, you can launch it manually by typing 'windsurf' in a terminal.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Could not find Windsurf executable. You can launch it manually by running: windsurf${NC}"
    return 1
}

# Function to install on Debian-based systems (Ubuntu, Debian, etc.)
install_debian() {
    echo -e "${BLUE}Installing Windsurf on Debian/Ubuntu-based system...${NC}"
    
    # Create keyrings directory if it doesn't exist
    mkdir -p /usr/share/keyrings
    
    # Download and install GPG key
    echo -e "${YELLOW}Downloading GPG key...${NC}"
    curl -fsSL "$WINDSURF_GPG_KEY_URL" | gpg --dearmor -o /usr/share/keyrings/windsurf-stable-archive-keyring.gpg
    
    # Add repository
    echo -e "${YELLOW}Adding repository...${NC}"
    echo "deb [signed-by=/usr/share/keyrings/windsurf-stable-archive-keyring.gpg arch=amd64] $WINDSURF_REPO_URL stable main" | tee /etc/apt/sources.list.d/windsurf.list > /dev/null
    
    # Update package lists
    echo -e "${YELLOW}Updating package lists...${NC}"
    apt-get update
    
    # Install Windsurf
    echo -e "${YELLOW}Installing Windsurf...${NC}"
    apt-get install -y windsurf
}

# Function to install on RHEL-based systems (Fedora, CentOS, RHEL)
install_rhel() {
    echo -e "${BLUE}Installing Windsurf on RHEL/Fedora-based system...${NC}"
    
    # Create RPM GPG key directory if it doesn't exist
    mkdir -p /etc/pki/rpm-gpg
    
    # Download and install GPG key
    echo -e "${YELLOW}Downloading GPG key...${NC}"
    curl -fsSL "$WINDSURF_GPG_KEY_URL" -o /etc/pki/rpm-gpg/windsurf-stable.gpg
    rpm --import /etc/pki/rpm-gpg/windsurf-stable.gpg
    
    # Add repository
    echo -e "${YELLOW}Adding repository...${NC}"
    cat > /etc/yum.repos.d/windsurf.repo << EOF
[windsurf]
name=Windsurf Repository
baseurl=$WINDSURF_REPO_URL
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/windsurf-stable.gpg
EOF
    
    # Install Windsurf using dnf or yum
    echo -e "${YELLOW}Installing Windsurf...${NC}"
    if command -v dnf > /dev/null; then
        dnf -y install windsurf
    else
        yum -y install windsurf
    fi
}

# Function to install on openSUSE
install_suse() {
    echo -e "${BLUE}Installing Windsurf on openSUSE...${NC}"
    
    # Create RPM GPG key directory if it doesn't exist
    mkdir -p /etc/pki/rpm-gpg
    
    # Download and install GPG key
    echo -e "${YELLOW}Downloading GPG key...${NC}"
    curl -fsSL "$WINDSURF_GPG_KEY_URL" -o /etc/pki/rpm-gpg/windsurf-stable.gpg
    rpm --import /etc/pki/rpm-gpg/windsurf-stable.gpg
    
    # Add repository
    echo -e "${YELLOW}Adding repository...${NC}"
    zypper addrepo -f -g -n "Windsurf Repository" $WINDSURF_REPO_URL windsurf
    
    # Install Windsurf
    echo -e "${YELLOW}Installing Windsurf...${NC}"
    zypper --non-interactive install windsurf
}

# Function to install on Arch Linux
install_arch() {
    echo -e "${BLUE}Installing Windsurf on Arch Linux...${NC}"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download and import GPG key
    echo -e "${YELLOW}Downloading GPG key...${NC}"
    curl -fsSL "$WINDSURF_GPG_KEY_URL" | pacman-key --add -
    pacman-key --lsign-key windsurf
    
    # Create PKGBUILD file for windsurf
    echo -e "${YELLOW}Creating PKGBUILD...${NC}"
    cat > PKGBUILD << EOF
# Maintainer: Windsurf Team
pkgname=windsurf
pkgver=1.0.0
pkgrel=1
pkgdesc="Windsurf application"
arch=('x86_64')
url="https://windsurf-stable.codeiumdata.com"
license=('proprietary')
depends=('libcurl')
source=("$WINDSURF_REPO_URL/pool/main/w/windsurf/windsurf_\${pkgver}_amd64.deb")
sha256sums=('SKIP')

package() {
  bsdtar -xf "windsurf_\${pkgver}_amd64.deb" data.tar.xz
  bsdtar -xf data.tar.xz -C "\${pkgdir}/"
}
EOF
    
    # Install Windsurf
    echo -e "${YELLOW}Installing Windsurf...${NC}"
    makepkg -si --noconfirm
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TMP_DIR"
}

# Function for other distributions - attempt generic installation or guide user
install_other() {
    echo -e "${YELLOW}Your distribution ($OS) is not directly supported by this script.${NC}"
    echo -e "${YELLOW}Attempting to detect compatible package manager...${NC}"
    
    if command -v apt-get > /dev/null; then
        echo -e "${GREEN}apt-get detected. Trying Debian/Ubuntu installation method...${NC}"
        install_debian
    elif command -v dnf > /dev/null || command -v yum > /dev/null; then
        echo -e "${GREEN}dnf/yum detected. Trying RHEL/Fedora installation method...${NC}"
        install_rhel
    elif command -v zypper > /dev/null; then
        echo -e "${GREEN}zypper detected. Trying openSUSE installation method...${NC}"
        install_suse
    elif command -v pacman > /dev/null; then
        echo -e "${GREEN}pacman detected. Trying Arch Linux installation method...${NC}"
        install_arch
    else
        echo -e "${RED}No supported package manager found.${NC}"
        echo -e "${YELLOW}Manual installation instructions:${NC}"
        echo "1. Download the GPG key: curl -fsSL $WINDSURF_GPG_KEY_URL -o windsurf.gpg"
        echo "2. Import the GPG key to your system's keyring"
        echo "3. Add the repository: $WINDSURF_REPO_URL"
        echo "4. Install the package 'windsurf' using your package manager"
        exit 1
    fi
}

# Main installation process
echo -e "${GREEN}=== Windsurf Installation Script ===${NC}"
echo -e "${BLUE}This script will install Windsurf on your system.${NC}"
echo

# Detect the OS
detect_os

# Install based on the detected OS
case "$OS" in
    ubuntu|debian|linuxmint|elementary|pop|zorin)
        install_debian
        ;;
    fedora|rhel|centos|almalinux|rocky|ol)
        install_rhel
        ;;
    opensuse*|suse|sles)
        install_suse
        ;;
    arch|manjaro|endeavouros)
        install_arch
        ;;
    *)
        # If OS_LIKE is defined, try to use that
        if [ -n "$OS_LIKE" ]; then
            case "$OS_LIKE" in
                *debian*)
                    install_debian
                    ;;
                *fedora*|*rhel*)
                    install_rhel
                    ;;
                *suse*)
                    install_suse
                    ;;
                *arch*)
                    install_arch
                    ;;
                *)
                    install_other
                    ;;
            esac
        else
            install_other
        fi
        ;;
esac

# Installation completed
echo
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo -e "${BLUE}Windsurf has been installed on your system.${NC}"

# Launch the application
launch_windsurf

echo -e "${BLUE}You can always run Windsurf by typing 'windsurf' in your terminal.${NC}" 