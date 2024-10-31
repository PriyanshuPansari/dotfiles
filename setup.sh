#!/usr/bin/env bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Repository URLs
REPO_URLS_OWNER=(
    "git@github.com:PriyanshuPansari/rofi-games.git"
    "git@github.com:PriyanshuPansari/lib_game_detector.git"
    "git@github.com:PriyanshuPansari/matugen-sddm-theme.git"
    "git@github.com:PriyanshuPansari/wallpapers.git"
    "git@github.com:PriyanshuPansari/dotfiles.git"
)

REPO_URLS_OTHER=(
    "https://github.com/PriyanshuPansari/rofi-games.git"
    "https://github.com/PriyanshuPansari/lib_game_detector.git"
    "https://github.com/PriyanshuPansari/matugen-sddm-theme.git"
    "https://github.com/PriyanshuPansari/wallpapers.git"
    "https://github.com/PriyanshuPansari/dotfiles.git"
)

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if command succeeded
check_error() {
    if [ $? -ne 0 ]; then
        print_message "$RED" "Error: $1"
        exit 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_message "$RED" "Please do not run this script as root"
        exit 1
    fi
}

# Function to detect owner vs other user
detect_user_type() {
    local owner_username="undead" # Replace with your actual username
    
    if [ "$USER" = "$owner_username" ]; then
        echo "owner"
    else
        echo "other"
    fi
}

# Function to prompt user for installation type
get_installation_type() {
    local detected_type=$(detect_user_type)
    local installation_type

    print_message "$YELLOW" "Detected user type: $detected_type"
    
    if [ "$detected_type" = "owner" ]; then
        print_message "$YELLOW" "Checking SSH key configuration..."
        if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            print_message "$RED" "SSH key not configured for GitHub. Falling back to HTTPS."
            installation_type="other"
        else
            installation_type="owner"
        fi
    else
        installation_type="other"
    fi

    print_message "$GREEN" "Using $([ "$installation_type" = "owner" ] && echo "SSH" || echo "HTTPS") URLs for git repositories"
    echo "$installation_type"
}

# Function to install base packages
install_base_packages() {
    print_message "$GREEN" "Installing base packages..."
    
    sudo pacman -S --needed --noconfirm git base-devel
    check_error "Failed to install base packages"
}

# Function to install yay
install_yay() {
    print_message "$GREEN" "Installing yay..."
    
    mkdir -p ~/clone
    cd ~/clone || exit 1
    
    if [ ! -d "yay" ]; then
        git clone https://aur.archlinux.org/yay.git
        check_error "Failed to clone yay"
    fi
    
    cd yay || exit 1
    makepkg -si --noconfirm
    check_error "Failed to install yay"
    
    cd ~ || exit 1
}

# Function to configure pacman
configure_pacman() {
    print_message "$GREEN" "Configuring pacman..."
    
    sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
    sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf
    
    if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
        sudo sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
    fi
}

# Function to install additional packages
install_packages() {
    print_message "$GREEN" "Installing additional packages..."
    
    yay -S --noconfirm hyprpolkitagent-git swww neovim waybar matugen rofi \
        ttf-jetbrains-mono-nerd wlogout swaync zsh cliphist yazi blueman lutris \
        cargo just qt5-graphicaleffects qt5-svg qt5-quickcontrols2
    check_error "Failed to install additional packages"
}

# Function to setup dotfiles
setup_dotfiles() {
    local installation_type=$1
    local url=$2

    print_message "$GREEN" "Cloning dotfiles repository..."
    
    cd ~/clone || exit 1
    git clone "$url" dotfiles
    check_error "Failed to clone dotfiles repository"

    # Ensure .config directory exists
    mkdir -p ~/.config

    # List of config directories to copy
    local configs=(
        "hypr"
        "waybar"
        "rofi"
        "swaync"
        "matugen"
        "wlogout"
        "nvim"
        "yazi"
        "zsh"
    )

    print_message "$YELLOW" "Copying configuration files..."
    
    for config in "${configs[@]}"; do
        if [ -d "$HOME/clone/dotfiles/.config/$config" ]; then
            cp -r "$HOME/clone/dotfiles/.config/$config" ~/.config/
            print_message "$GREEN" "Copied $config configuration"
        else
            print_message "$YELLOW" "No configuration found for $config"
        fi
    done

    # Special handling for global configs
    if [ -d "$HOME/clone/dotfiles/.zshrc" ]; then
        cp "$HOME/clone/dotfiles/.zshrc" ~/ && print_message "$GREEN" "Copied .zshrc"
    fi

    # Ask for further customization in non-owner case
    if [ "$installation_type" = "other" ]; then
        read -p "Would you like to review and customize the copied configurations? (y/n): " customize
        if [ "$customize" = "y" ]; then
            print_message "$YELLOW" "Please manually review and modify configurations in ~/.config"
        fi
    fi
}

# Function to clone repositories
clone_repos() {
    local installation_type=$1
    local urls=()
    
    if [ "$installation_type" = "owner" ]; then
        urls=("${REPO_URLS_OWNER[@]}")
    else
        urls=("${REPO_URLS_OTHER[@]}")
    fi
    
    cd ~/clone || exit 1
    
    # Clone rofi-games and lib_game_detector
    git clone "${urls[0]}"
    check_error "Failed to clone rofi-games"
    
    git clone "${urls[1]}"
    check_error "Failed to clone lib_game_detector"
    
    # Install rofi-games
    cd rofi-games || exit 1
    sudo just install
    check_error "Failed to install rofi-games"
    
    # Install SDDM theme
    cd ~/clone || exit 1
    git clone "${urls[2]}"
    sudo cp -r matugen-sddm-theme /usr/share/sddm/themes/matugen
    mkdir -p /etc/sddm.conf.d/
    echo -e "[Theme]\nCurrent=matugen" | sudo tee /etc/sddm.conf.d/sddm.conf
    sudo chown -R "$USER:$USER" /usr/share/sddm/themes/matugen/backgrounds
    sudo chown -R "$USER:$USER" /usr/share/sddm/themes/matugen/theme.conf
    
    # Install wallpapers
    mkdir -p ~/Pictures
    cd ~/Pictures || exit 1
    git clone "${urls[3]}"
    
    # Setup dotfiles
    setup_dotfiles "$installation_type" "${urls[4]}"
    
    cd ~ || exit 1
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    print_message "$GREEN" "Installing Oh My Zsh..."
    
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    check_error "Failed to install Oh My Zsh"
}

install_grub_theme() {
    print_message "$GREEN" "Installing Yorha GRUB theme..."
    
    # Create themes directory if it doesn't exist
    sudo mkdir -p /boot/grub/themes
    
    # Clone the Yorha GRUB theme repository
    cd ~/clone || exit 1
    git clone https://github.com/OliveThePuffin/yorha-grub-theme.git
    check_error "Failed to clone Yorha GRUB theme repository"
    
    # Detect screen resolution
    resolution=$(xrandr | grep '*' | awk '{print $1}' | head -n 1)
    
    if [ -z "$resolution" ]; then
        print_message "$YELLOW" "Could not automatically detect screen resolution. Please manually select a theme folder."
        resolution="1920x1080"  # Default fallback
    fi
    
    # Find matching theme folder
    theme_folder=$(find ~/clone/yorha-grub-theme -type d -name "*$resolution" | head -n 1)
    
    if [ -z "$theme_folder" ]; then
        print_message "$RED" "No theme found for resolution $resolution. Using default 1920x1080."
        theme_folder=$(find ~/clone/yorha-grub-theme -type d -name "*1920x1080" | head -n 1)
    fi
    
    if [ -n "$theme_folder" ]; then
        # Copy theme to GRUB themes directory
        sudo cp -r "$theme_folder" /boot/grub/themes/
        
        # Modify GRUB configuration
        theme_name=$(basename "$theme_folder")
        sudo sed -i "s|^#*GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/$theme_name/theme.txt\"|" /etc/default/grub
        
        # Update GRUB
        sudo update-grub
        
        print_message "$GREEN" "GRUB theme installed successfully for resolution $resolution"
    else
        print_message "$RED" "Failed to find a suitable GRUB theme folder"
        exit 1
    fi
    
    cd ~ || exit 1
}

# Main function
main() {
    check_root
    
    print_message "$GREEN" "Starting system setup..."
    
    local installation_type
    installation_type=$(get_installation_type)
    
    install_base_packages
    install_yay
    configure_pacman
    install_packages
    clone_repos "$installation_type"
    install_oh_my_zsh
    
    # Add GRUB theming step
    read -p "Would you like to install the Yorha GRUB theme? (y/n): " install_grub
    if [ "$install_grub" = "y" ]; then
        install_grub_theme
    fi
    
    print_message "$GREEN" "Setup completed successfully!"
    print_message "$YELLOW" "Please log out and back in for all changes to take effect."
    print_message "$YELLOW" "Review and adjust configurations in ~/.config as needed."
}

# Run main function
main "$@"
