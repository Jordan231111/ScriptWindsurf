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
AUTO_REGISTER=${AUTO_REGISTER:-false} # Set to true to enable automatic registration

# Check if running as root or with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo${NC}"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install dependencies if needed
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    local deps_to_install=()
    
    # Check for curl
    if ! command_exists curl; then
        deps_to_install+=("curl")
    fi
    
    # Check for jq (for JSON parsing)
    if ! command_exists jq; then
        deps_to_install+=("jq")
    fi
    
    # Install missing dependencies
    if [ ${#deps_to_install[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing required dependencies: ${deps_to_install[*]}${NC}"
        
        if command_exists apt-get; then
            apt-get update
            apt-get install -y "${deps_to_install[@]}"
        elif command_exists dnf; then
            dnf install -y "${deps_to_install[@]}"
        elif command_exists yum; then
            yum install -y "${deps_to_install[@]}"
        elif command_exists zypper; then
            zypper install -y "${deps_to_install[@]}"
        elif command_exists pacman; then
            pacman -Sy --noconfirm "${deps_to_install[@]}"
        else
            echo -e "${RED}Unable to install dependencies automatically. Please install ${deps_to_install[*]} manually.${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}All dependencies are installed.${NC}"
}

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

# Function to get a temporary email address from temp-mail.org
get_temp_email() {
    echo -e "${BLUE}Getting a temporary email address...${NC}"
    
    # Using temp-mail.org API to get a temporary email
    local response=$(curl -s "https://api.temp-mail.org/request/domains/format/json")
    local domain=$(echo "$response" | jq -r '.[] | select(. != null) | .[0]')
    
    if [ -z "$domain" ]; then
        echo -e "${RED}Failed to get a domain from temp-mail.org${NC}"
        return 1
    fi
    
    # Generate a random username
    local username=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
    local email="${username}@${domain}"
    
    echo -e "${GREEN}Temporary email address: $email${NC}"
    echo "$email"
}

# Function to check for emails in the temporary mailbox
check_temp_email() {
    local email="$1"
    local username=$(echo "$email" | cut -d@ -f1)
    local domain=$(echo "$email" | cut -d@ -f2)
    
    echo -e "${BLUE}Checking temporary mailbox for messages...${NC}"
    
    # Hash the email for the API request
    local hash=$(echo -n "$username@$domain" | md5sum | cut -d' ' -f1)
    
    # Check for messages
    local messages=$(curl -s "https://api.temp-mail.org/request/mail/id/$hash/format/json")
    
    echo "$messages"
}

# Function to extract 2FA code from email content
extract_2fa_code() {
    local email_content="$1"
    
    echo -e "${BLUE}Extracting 2FA code from email...${NC}"
    
    # Pattern to match a 6-digit verification code based on the Windsurf email format
    # Looking for patterns like "909318" in the email
    local code=$(echo "$email_content" | grep -o -E '[0-9]{6}' | head -n 1)
    
    if [ -z "$code" ]; then
        echo -e "${RED}Failed to extract verification code from email${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Extracted verification code: $code${NC}"
    echo "$code"
}

# Function to register Windsurf with temporary email and 2FA
register_windsurf() {
    if [ "$AUTO_REGISTER" != "true" ]; then
        echo -e "${YELLOW}Automatic registration is disabled. Skipping...${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Starting automatic Windsurf registration with browser automation...${NC}"
    
    # Check for Python (needed for Selenium)
    if ! command_exists python3; then
        echo -e "${YELLOW}Installing Python 3 for browser automation...${NC}"
        if command_exists apt-get; then
            apt-get update && apt-get install -y python3 python3-pip python3-venv
        elif command_exists dnf; then
            dnf install -y python3 python3-pip python3-venv
        elif command_exists yum; then
            yum install -y python3 python3-pip python3-venv
        elif command_exists zypper; then
            zypper install -y python3 python3-pip python3-venv
        elif command_exists pacman; then
            pacman -Sy --noconfirm python python-pip python-virtualenv
        else
            echo -e "${RED}Could not install Python 3. Please install it manually.${NC}"
            echo -e "${YELLOW}You will need to register manually when you first run Windsurf.${NC}"
            return 1
        fi
    else
        # Ensure venv module is installed
        echo -e "${YELLOW}Ensuring Python virtual environment module is installed...${NC}"
        if command_exists apt-get; then
            apt-get update && apt-get install -y python3-venv
        elif command_exists dnf; then
            dnf install -y python3-venv
        elif command_exists yum; then
            yum install -y python3-venv
        elif command_exists zypper; then
            zypper install -y python3-venv
        elif command_exists pacman; then
            pacman -Sy --noconfirm python-virtualenv
        fi
    fi
    
    # Create a virtual environment for Python packages
    echo -e "${BLUE}Creating Python virtual environment...${NC}"
    VENV_DIR=$(mktemp -d)/windsurf_venv
    python3 -m venv "$VENV_DIR"
    
    # Install required Python packages for browser automation
    echo -e "${BLUE}Installing required Python packages for browser automation...${NC}"
    # Use the pip from the virtual environment
    "$VENV_DIR/bin/pip" install selenium webdriver-manager requests faker
    
    # Check if Chrome or Firefox is installed
    BROWSER=""
    WEBDRIVER=""
    
    if command_exists google-chrome || command_exists google-chrome-stable; then
        BROWSER="chrome"
        WEBDRIVER="chrome"
    elif command_exists firefox; then
        BROWSER="firefox"
        WEBDRIVER="firefox"
    else
        echo -e "${YELLOW}Installing Google Chrome for browser automation...${NC}"
        if command_exists apt-get; then
            wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
            echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
            apt-get update && apt-get install -y google-chrome-stable
            BROWSER="chrome"
            WEBDRIVER="chrome"
        elif command_exists dnf; then
            dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
            BROWSER="chrome"
            WEBDRIVER="chrome"
        elif command_exists zypper; then
            zypper install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
            BROWSER="chrome"
            WEBDRIVER="chrome"
        else
            echo -e "${RED}Could not install a supported browser. Please install Chrome or Firefox manually.${NC}"
            echo -e "${YELLOW}You will need to register manually when you first run Windsurf.${NC}"
            return 1
        fi
    fi
    
    # Get a temporary email
    local temp_email=$(get_temp_email)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to get temporary email. Registration aborted.${NC}"
        return 1
    fi
    
    # Create Python script for browser automation
    local automation_script=$(mktemp --suffix=.py)
    echo -e "${BLUE}Creating browser automation script...${NC}"
    
    cat > "$automation_script" << EOF
#!/usr/bin/env python3
import os
import time
import re
import sys
import json
import string
import random
import hashlib
import tempfile
import requests
import os
from faker import Faker
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException, SessionNotCreatedException
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.firefox import GeckoDriverManager
import secrets

# Define color constants for Python script
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[0;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

# Initialize Faker to generate random names
fake = Faker()

def setup_driver(browser_type):
    """Setup and configure the WebDriver"""
    print(f"Setting up {browser_type} browser...")
    
    if browser_type == "chrome":
        from selenium.webdriver.chrome.options import Options
        from selenium.webdriver.chrome.service import Service
        import shutil
        from contextlib import closing
        
        # Maximum retries for browser setup
        max_retries = 3
        retry_count = 0
        last_exception = None
        
        while retry_count < max_retries:
            try:
                options = Options()
                # Always start fresh - useful for automation
                options.add_argument("--incognito")
                options.add_argument("--no-sandbox")
                options.add_argument("--disable-dev-shm-usage")
                options.add_argument("--disable-blink-features=AutomationControlled")
                options.add_argument("--disable-extensions")
                options.add_argument("--disable-gpu")
                
                # Handle user data directory differently in each retry
                if retry_count == 0:
                    # First try: Use a unique user data directory
                    unique_user_dir = tempfile.mkdtemp()
                    options.add_argument(f"--user-data-dir={unique_user_dir}")
                    print(f"Using unique user data dir: {unique_user_dir}")
                elif retry_count == 1:
                    # Second try: No custom user data directory
                    print("Trying without custom user-data-dir")
                    # No user-data-dir setting
                else:
                    # Last try: Force temporary directory and use --remote-debugging-port
                    unique_user_dir = tempfile.mkdtemp()
                    options.add_argument(f"--user-data-dir={unique_user_dir}")
                    options.add_argument("--remote-debugging-port=9222")
                    print(f"Last attempt with remote debugging port and dir: {unique_user_dir}")
                
                options.add_experimental_option("excludeSwitches", ["enable-automation"])
                options.add_experimental_option("useAutomationExtension", False)
                
                service = Service(ChromeDriverManager().install())
                driver = webdriver.Chrome(service=service, options=options)
                return driver  # Success!
                
            except SessionNotCreatedException as e:
                retry_count += 1
                last_exception = e
                print(f"Browser setup failed (attempt {retry_count}/{max_retries}): {e}")
                # Clean up any temp directories we created
                if 'unique_user_dir' in locals() and os.path.exists(unique_user_dir):
                    try:
                        shutil.rmtree(unique_user_dir)
                        print(f"Cleaned up temporary directory: {unique_user_dir}")
                    except Exception as cleanup_error:
                        print(f"Failed to clean up directory {unique_user_dir}: {cleanup_error}")
                        
                if retry_count >= max_retries:
                    print(f"Failed to start Chrome after {max_retries} attempts")
                    raise last_exception
    elif browser_type == "firefox":
        from selenium.webdriver.firefox.options import Options
        from selenium.webdriver.firefox.service import Service
        
        options = Options()
        # Comment out the headless option to see the browser in action (for debugging)
        # options.add_argument("--headless")
        service = Service(GeckoDriverManager().install())
        driver = webdriver.Firefox(service=service, options=options)
    else:
        print("Unsupported browser type")
        sys.exit(1)
    
    # Set window size
    driver.set_window_size(1366, 768)
    
    # Add stealth JS to avoid detection
    driver.execute_script(
        "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
    )
    
    return driver

def generate_user_info():
    """Generate random user information"""
    first_name = fake.first_name()
    last_name = fake.last_name()
    return {
        "first_name": first_name,
        "last_name": last_name,
        "password": generate_strong_password()
    }

def generate_strong_password(length=12):
    """Generate a strong random password"""
    characters = string.ascii_letters + string.digits + "!@#$%^&*()_+"
    password = ''.join(secrets.choice(characters) for _ in range(length))
    return password

def check_email_for_verification(email, max_attempts=40, delay=5):
    """Poll the temporary email service for the verification code"""
    username, domain = email.split('@')
    email_hash = hashlib.md5(f"{username}@{domain}".encode()).hexdigest()
    
    print(f"Checking for verification emails for {email}...")
    
    for attempt in range(max_attempts):
        print(f"Checking for verification email... attempt {attempt+1}/{max_attempts}")
        
        try:
            response = requests.get(f"https://api.temp-mail.org/request/mail/id/{email_hash}/format/json")
            data = response.json()
            
            if data and isinstance(data, list) and len(data) > 0:
                for mail in data:
                    mail_text = mail.get("mail_text", "")
                    mail_subject = mail.get("mail_subject", "")
                    
                    if "Windsurf" in mail_subject or "Windsurf" in mail_text or "verification" in mail_text.lower():
                        # Look for a 6-digit code in the email
                        code_match = re.search(r'(\d{6})', mail_text)
                        if code_match:
                            return code_match.group(1)
                        
                        # Try to find numbers in different formats
                        code_match = re.search(r'(\d[\s\-]*\d[\s\-]*\d[\s\-]*\d[\s\-]*\d[\s\-]*\d)', mail_text)
                        if code_match:
                            return re.sub(r'[\s\-]', '', code_match.group(1))
        except Exception as e:
            print(f"Error checking email: {e}")
            # Continue despite errors
        
        time.sleep(delay)
    
    return None

def save_credentials(user_info, email):
    """Save credentials to a file for future reference"""
    config_dir = os.path.expanduser("~/.config/windsurf")
    os.makedirs(config_dir, exist_ok=True)
    
    credentials = {
        "email": email,
        "first_name": user_info["first_name"],
        "last_name": user_info["last_name"],
        "password": user_info["password"],
        "registration_date": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    with open(f"{config_dir}/credentials.json", "w") as f:
        json.dump(credentials, f, indent=2)
    
    return credentials

def register_windsurf(email, webdriver_type="chrome"):
    """Register a new Windsurf account using browser automation"""
    print("Starting browser automation to register Windsurf...")
    
    user_info = generate_user_info()
    driver = None
    try:
        driver = setup_driver(webdriver_type)
        # Step 1: Navigate to Windsurf registration page
        print("Step 1: Navigating to Windsurf registration page...")
        driver.get("https://windsurf.com/account/register")
        
        # Wait for the registration form to load
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.TAG_NAME, "form"))
        )
        
        # Step 2: Fill in the registration form with user details
        print(f"Step 2: Filling registration form with:\n"
              f"  First Name: {user_info['first_name']}\n"
              f"  Last Name: {user_info['last_name']}\n"
              f"  Email: {email}")
        
        # Find and fill in the name fields
        first_name_field = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "firstName"))
        )
        first_name_field.clear()
        first_name_field.send_keys(user_info["first_name"])
        
        last_name_field = driver.find_element(By.ID, "lastName")
        last_name_field.clear()
        last_name_field.send_keys(user_info["last_name"])
        
        # Find and fill in the email field
        email_field = driver.find_element(By.ID, "email")
        email_field.clear()
        email_field.send_keys(email)
        
        # Step 3: Submit the form to proceed to password creation
        print("Step 3: Submitting the initial registration form...")
        
        # Find and click the Continue button
        continue_button = driver.find_element(By.XPATH, "//button[contains(text(), 'Continue') or contains(text(), 'Next')]")
        continue_button.click()
        
        # Step 4: Wait for the password page and create password
        print("Step 4: Creating password...")
        
        # Wait for password field
        password_field = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.ID, "password"))
        )
        password_field.clear()
        password_field.send_keys(user_info["password"])
        
        # Find and fill confirmation password if it exists
        try:
            confirm_password_field = driver.find_element(By.ID, "confirmPassword")
            confirm_password_field.clear()
            confirm_password_field.send_keys(user_info["password"])
        except NoSuchElementException:
            print("No confirmation password field found, continuing...")
        
        # Submit the password form
        password_submit = driver.find_element(By.XPATH, "//button[contains(text(), 'Continue') or contains(text(), 'Submit') or contains(text(), 'Register')]")
        password_submit.click()
        
        # Step 5: Wait for verification code request
        print("Step 5: Waiting for verification screen...")
        
        # Wait for verification form
        WebDriverWait(driver, 30).until(
            EC.presence_of_element_located((By.XPATH, "//div[contains(text(), 'verification') or contains(text(), 'Verify') or contains(text(), 'code')]"))
        )
        
        # Step 6: Get verification code from email
        print("Step 6: Checking email for verification code...")
        verification_code = check_email_for_verification(email)
        
        if not verification_code:
            print("Failed to get verification code from email.")
            return False
        
        print(f"Step 7: Verification code received: {verification_code}")
        
        # Step 7: Enter each digit of the code into separate input boxes
        print("Entering verification code digits...")
        
        # Find all input fields for the verification code
        # Look for various ways verification inputs might be organized
        try:
            # Try to find inputs within a verification container
            verification_inputs = driver.find_elements(By.XPATH, "//div[contains(@class, 'verification') or contains(@class, 'code')]//input")
            
            # If no specific container, look for numbered inputs or just find all digit inputs
            if not verification_inputs:
                verification_inputs = driver.find_elements(By.XPATH, "//input[@type='text' and (@maxlength='1' or @size='1')]")
            
            # If still no luck, look for any small text inputs that might be for codes
            if not verification_inputs:
                verification_inputs = driver.find_elements(By.XPATH, "//input[(@type='text' or @type='number') and (@maxlength<='2')]")
                
            # As a last resort, find the first 6 inputs
            if not verification_inputs or len(verification_inputs) < 6:
                verification_inputs = driver.find_elements(By.TAG_NAME, "input")[:6]
                
            # Enter each digit into the corresponding input field
            if len(verification_inputs) >= len(verification_code):
                for i, digit in enumerate(verification_code):
                    verification_inputs[i].clear()
                    verification_inputs[i].send_keys(digit)
                    time.sleep(0.2)  # Small delay between inputs to simulate human typing
            else:
                # If we don't have individual boxes, try to find a single input field
                verification_input = driver.find_element(By.XPATH, "//input[contains(@placeholder, 'code') or contains(@id, 'code')]")
                verification_input.clear()
                verification_input.send_keys(verification_code)
        except Exception as e:
            print(f"Error entering verification code: {e}")
            # Take a screenshot to help debug
            driver.save_screenshot("/tmp/verification_screen.png")
            print("Screenshot saved to /tmp/verification_screen.png")
            
            # Try one more approach - just find all inputs and enter code in the first one
            try:
                inputs = driver.find_elements(By.TAG_NAME, "input")
                if inputs:
                    inputs[0].clear()
                    inputs[0].send_keys(verification_code)
            except:
                pass
        
        # Step 8: Submit the verification code
        print("Step 8: Submitting verification code...")
        
        # Look for verify/continue button
        try:
            verify_button = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Verify') or contains(text(), 'Submit') or contains(text(), 'Continue')]"))
            )
            verify_button.click()
        except:
            # If no button found, try pressing Enter on the last input
            try:
                from selenium.webdriver.common.keys import Keys
                verification_inputs[-1].send_keys(Keys.ENTER)
            except:
                print("Could not find a way to submit verification code")
        
        # Step 9: Wait for registration success
        print("Step 9: Waiting for registration to complete...")
        
        # Wait for confirmation of successful registration
        try:
            WebDriverWait(driver, 30).until(
                EC.presence_of_element_located((By.XPATH, "//div[contains(text(), 'success') or contains(text(), 'welcome') or contains(text(), 'complete')]"))
            )
            print("Registration successful!")
        except TimeoutException:
            # Even if we don't see success message, we might have succeeded
            print("Could not confirm registration success, but proceeding anyway...")
        
        # Step 10: Save credentials and display them
        credentials = save_credentials(user_info, email)
        
        print("\n============ REGISTRATION COMPLETE ============")
        print(f"Email: {email}")
        # Check if the registration was successful
        if "dashboard" in driver.current_url.lower() or "welcome" in driver.current_url.lower():
            print(f"\n{GREEN}Registration successful!{NC}")
            return True
        else:
            print(f"\n{YELLOW}Registration might not be complete. Please check manually.{NC}")
            return False
    except Exception as e:
        print(f"\n{RED}Error during registration: {e}{NC}")
        return False
    finally:
        # Ensure browser is always closed properly
        if driver:
            # Capture screenshot for debugging before closing
            try:
                driver.save_screenshot("/tmp/windsurf_registration_final.png")
                print("Final screenshot saved to /tmp/windsurf_registration_final.png")
            except:
                pass
            
            # Keep the browser open for a moment to see the final state
            time.sleep(5)
            
            # Close the browser
            try:
                driver.quit()
                print("Browser closed successfully.")
            except Exception as e:
                print(f"Error closing browser: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python script.py <email> <webdriver_type>")
        sys.exit(1)
    
    email = sys.argv[1]
    webdriver_type = sys.argv[2]
    
    success = register_windsurf(email, webdriver_type)
    
    if success:
        sys.exit(0)
    else:
        sys.exit(1)
EOF
    
    # Make script executable
    chmod +x "$automation_script"
    
    # Create a credentials file to store registration info
    mkdir -p "$HOME/.config/windsurf"
    
    # Run the automation script
    echo -e "${BLUE}Starting browser automation to register Windsurf...${NC}"
    "$VENV_DIR/bin/python" "$automation_script" "$temp_email" "$WEBDRIVER"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Windsurf registration completed successfully!${NC}"
        
        # Display the credentials from saved file
        if [ -f "$HOME/.config/windsurf/credentials.json" ]; then
            echo -e "${GREEN}================== LOGIN CREDENTIALS ==================${NC}"
            echo -e "${BLUE}Email:${NC} $(jq -r '.email' $HOME/.config/windsurf/credentials.json)"
            echo -e "${BLUE}Password:${NC} $(jq -r '.password' $HOME/.config/windsurf/credentials.json)"
            echo -e "${GREEN}=====================================================${NC}"
            echo -e "${YELLOW}These credentials are also saved in:${NC} $HOME/.config/windsurf/credentials.json"
        fi
        
        # Clean up the virtual environment
        echo -e "${BLUE}Cleaning up virtual environment...${NC}"
        rm -rf "$(dirname "$VENV_DIR")"
        
        return 0
    else
        echo -e "${RED}Failed to register Windsurf automatically.${NC}"
        echo -e "${YELLOW}You will need to register manually when you first run Windsurf.${NC}"
        echo -e "${YELLOW}Check /tmp/windsurf_registration_final.png for debugging information.${NC}"
        
        # Clean up the virtual environment even on failure
        echo -e "${BLUE}Cleaning up virtual environment...${NC}"
        rm -rf "$(dirname "$VENV_DIR")"
        
        return 1
    fi
}

# Function to launch the Windsurf GUI application with proper arguments
launch_windsurf() {
    # Check if running as root/sudo
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${YELLOW}Running as root/sudo - adding required arguments${NC}"
        windsurf --no-sandbox --user-data-dir=/tmp/windsurf-root
    else
        windsurf
    fi
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

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --auto-register       Enable automatic registration with temp email and 2FA"
    echo "  --help                Show this help message"
    echo
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --auto-register)
                AUTO_REGISTER=true
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Main installation process
main() {
    echo -e "${GREEN}=== Windsurf Installation Script ===${NC}"
    echo -e "${BLUE}This script will install Windsurf on your system.${NC}"
    echo
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check and install dependencies
    check_dependencies
    
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
    
    # Automatically register if enabled
    if [ "$AUTO_REGISTER" = "true" ]; then
        register_windsurf
    fi
    
    # Launch the application
    launch_windsurf
    
    echo -e "${BLUE}You can always run Windsurf by typing 'windsurf' in your terminal.${NC}"
}

# Execute main function with all script arguments
main "$@" 