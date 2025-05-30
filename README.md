# ScriptWindsurf

A universal installation script for Windsurf that works across all major Linux distributions.

## Supported Distributions

- Debian/Ubuntu-based systems (Ubuntu, Debian, Linux Mint, Pop!_OS, etc.)
- RHEL/Fedora-based systems (Fedora, CentOS, Rocky Linux, etc.)
- openSUSE
- Arch Linux and derivatives
- Other distributions with apt, dnf/yum, zypper, or pacman package managers

## Features

- Automatic OS detection
- Distribution-specific installation
- Secure GPG key handling
- Proper repository configuration
- Automatic application launch after installation
- Fallback mechanisms for non-standard distributions

## Quick Installation

To install Windsurf, you can use the following one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Jordan231111/ScriptWindsurf/main/install_windsurf.sh | sudo bash
```

This command will:
1. Download the installation script securely via HTTPS
2. Execute it with sudo privileges to install Windsurf
3. Launch the Windsurf application if you're in a graphical environment

## Security Note

The one-liner above downloads the script via HTTPS and executes it directly. For enhanced security, you may prefer to inspect the script before running it:

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/Jordan231111/ScriptWindsurf/main/install_windsurf.sh -o install_windsurf.sh

# Inspect the script
less install_windsurf.sh

# Make it executable
chmod +x install_windsurf.sh

# Run the script
sudo ./install_windsurf.sh
```

## Manual Installation

If you prefer to install Windsurf manually, the script can guide you through the process even if your distribution isn't directly supported:

1. Download the GPG key: `curl -fsSL "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | sudo gpg --dearmor -o /usr/share/keyrings/windsurf-stable-archive-keyring.gpg`
2. Add the repository: `echo "deb [signed-by=/usr/share/keyrings/windsurf-stable-archive-keyring.gpg arch=amd64] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null`
3. Update package lists: `sudo apt-get update`
4. Install Windsurf: `sudo apt-get install windsurf`

## License

See the [LICENSE](LICENSE) file for details. 
