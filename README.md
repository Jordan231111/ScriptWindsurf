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
- Automatic registration with temporary email and 2FA (optional)

## Quick Installation

To install Windsurf, you can use the following one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Jordan231111/ScriptWindsurf/main/install_windsurf.sh | sudo bash
```

If you want to enable automatic registration with a temporary email address and 2FA:

```bash
curl -fsSL https://raw.githubusercontent.com/Jordan231111/ScriptWindsurf/main/install_windsurf.sh | sudo bash -s -- --auto-register
```

## Security Notice

The installation script requires root privileges to:
1. Add the Windsurf repository
2. Install necessary packages
3. Configure system settings

For security, we recommend reviewing the script before execution:

```bash
curl -fsSL https://raw.githubusercontent.com/Jordan231111/ScriptWindsurf/main/install_windsurf.sh -o install_windsurf.sh
less install_windsurf.sh  # Review the code
chmod +x install_windsurf.sh
sudo ./install_windsurf.sh
```

## Advanced Usage

The script supports several command-line options:

```
Usage: ./install_windsurf.sh [OPTIONS]

Options:
  --auto-register       Enable automatic registration with temp email and 2FA
  --help                Show this help message
```

### Automatic Registration

The `--auto-register` option enables a streamlined registration process that:

1. Obtains a temporary email address from temp-mail.org
2. Uses that email for Windsurf registration
3. Automatically retrieves the 2FA code sent to that email
4. Completes the registration process

This is useful for:
- Automated deployments
- Testing environments
- CI/CD pipelines

## Dependencies

The script will automatically install required dependencies:
- curl (for downloading packages and API calls)
- jq (for JSON parsing)

## Troubleshooting

If you encounter issues:

1. Check your system's package manager is working correctly
2. Ensure you have internet connectivity
3. Verify the GPG key and repository URLs are accessible
4. For registration issues, check if temp-mail.org is accessible from your network

## License

[MIT License](LICENSE) 
