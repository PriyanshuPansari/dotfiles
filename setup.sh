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

check_repo() {
    local dir=$1
    if [ -d "$dir/.git" ]; then
        return 0
    else
        return 1
    fi
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
    # Remove all the print statements for now
    local owner_username="undead"
    
    if [ "$USER" = "$owner_username" ]; then
        if ssh -T git@github.com 2>&1 | grep -qi "authenticated"; then
            echo "owner"
        else
            echo "other"
        fi
    else
        echo "other"
    fi
}

# Function to install base packages
install_base_packages() {
    print_message "$GREEN" "Installing base packages..."
    
    sudo pacman -S --needed --noconfirm git base-devel stow
    check_error "Failed to install base packages"
}

# Function to install yay
install_yay() {
    print_message "$GREEN" "Installing yay..."
    
    mkdir -p ~/clone
    cd ~/clone || exit 1
    
    if check_repo "yay"; then
        print_message "$YELLOW" "Yay repository exists, updating..."
        cd yay || exit 1
        git pull
        check_error "Failed to update yay"
    else
        git clone https://aur.archlinux.org/yay.git
        check_error "Failed to clone yay"
        cd yay || exit 1
    fi
    
    makepkg -si --noconfirm
    check_error "Failed to install yay"
    
    cd ~ || exit 1
}
# Function to install additional packages
install_packages() {
    print_message "$GREEN" "Installing additional packages..."
    yes y| yay -S hyprutils-git 
    yay -S --noconfirm hyprpolkitagent-git swww neovim waybar matugen rofi \
        ttf-jetbrains-mono-nerd wlogout swaync zsh cliphist yazi blueman lutris \
        cargo just qt5-graphicaleffects qt5-svg qt5-quickcontrols2 stow brightnessctl hypridle \
        pavucontrol hyprlock jq pipewire pipewire-pulse wireplumber bluez bluez-libs bluez-utils ripgrep libva-nvidia-driver \
        pamixer kvantum pipewire-alsa qt5ct qt6ct qt6-svg xsg-utils yad
    check_error "Failed to install additional packages"
}

# Updated function to setup dotfiles using stow
setup_dotfiles() {
    local installation_type=$1
    local url=$2

    print_message "$GREEN" "Setting up dotfiles with GNU Stow..."
    
    # Clone dotfiles to ~/.dotfiles instead of ~/clone/dotfiles
    cd ~ || exit 1
    
    # Backup existing .dotfiles if it exists
    if [ -d "$HOME/.dotfiles" ]; then
        print_message "$YELLOW" "Backing up existing .dotfiles directory..."
        mv "$HOME/.dotfiles" "$HOME/.dotfiles.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Clone the dotfiles repository
    git clone "$url" "$HOME/.dotfiles"
    check_error "Failed to clone dotfiles repository"
    
    cd "$HOME/.dotfiles" || exit 1
    
    # List of stow packages (directories in your dotfiles repo)
    local stow_packages=(
        "hypr"
        "waybar"
        "rofi"
        "swaync"
        "matugen"
        "wlogout"
        "nvim"
        "yazi"
        "zsh"
        "kitty"
    )
    rm -rf ~/.config/kitty 
    # Backup existing configs before stowing
    print_message "$YELLOW" "Backing up existing configurations..."
    for package in "${stow_packages[@]}"; do
        if [ -d "$HOME/.config/$package" ]; then
            mv "$HOME/.config/$package" "$HOME/.config/$package.backup.$(date +%Y%m%d_%H%M%S)"
            print_message "$GREEN" "Backed up $package configuration"
        fi
    done
    
    # Special handling for .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        print_message "$GREEN" "Backed up .zshrc"
    fi
    
    # Stow each package
    print_message "$GREEN" "Stowing configuration packages..."
    for package in "${stow_packages[@]}"; do
        if [ -d "$package" ]; then
            stow -v "$package"
            check_error "Failed to stow $package"
            print_message "$GREEN" "Stowed $package configuration"
        else
            print_message "$YELLOW" "No configuration found for $package"
        fi
    done
    
    # Ask for further customization in non-owner case
    if [ "$installation_type" = "other" ]; then
        read -p "Would you like to review and customize the stowed configurations? (y/n): " customize
        if [ "$customize" = "y" ]; then
            print_message "$YELLOW" "Please manually review and modify configurations in ~/.config"
            print_message "$YELLOW" "You can restow configurations after modifications using 'stow -R <package>'"
        fi
    fi
    
    cd ~ || exit 1
}

# Function to update or clone repository
update_or_clone_repo() {
    local url=$1
    local dir=$2
    local repo_name=$(basename "$url" .git)

    if check_repo "$dir/$repo_name"; then
        print_message "$YELLOW" "Repository $repo_name exists, updating..."
        cd "$dir/$repo_name" || exit 1
        git pull
        check_error "Failed to update $repo_name"
        cd - > /dev/null || exit 1
    else
        print_message "$GREEN" "Cloning $repo_name..."
        git clone "$url" "$dir/$repo_name"
        check_error "Failed to clone $repo_name"
    fi
}
# Function to clone repositories
clone_repos() {
    local installation_type=$1
    local -a urls
    
    echo -n "$installation_type" | xxd
    
    if [ "$installation_type" = "owner" ]; then
        urls=("${REPO_URLS_OWNER[@]}")
        print_message "$GREEN" "Using SSH URLs for repositories"
    else
        urls=("${REPO_URLS_OTHER[@]}")
        print_message "$GREEN" "Using HTTPS URLs for repositories"
    fi
    mkdir -p ~/clone
    cd ~/clone || exit 1
    
    # Update or clone rofi-games and lib_game_detector
    update_or_clone_repo "${urls[0]}" ~/clone
    update_or_clone_repo "${urls[1]}" ~/clone
    
    # Install rofi-games
    cd ~/clone/rofi-games || exit 1
    sudo just install
    check_error "Failed to install rofi-games"
    
    # Update or install SDDM theme
    cd ~/clone || exit 1
    update_or_clone_repo "${urls[2]}" ~/clone
    sudo cp -r matugen-sddm-theme /usr/share/sddm/themes/matugen
    sudo mkdir -p /etc/sddm.conf.d/
    echo -e "[Theme]\nCurrent=matugen" | sudo tee /etc/sddm.conf.d/sddm.conf
    sudo chown -R "$USER:$USER" /usr/share/sddm/themes/matugen/backgrounds
    sudo chown -R "$USER:$USER" /usr/share/sddm/themes/matugen/theme.conf
    
    # Update or install wallpapers
    mkdir -p ~/Pictures
    cd ~/Pictures || exit 1
    update_or_clone_repo "${urls[3]}" ~/Pictures
    
    # Setup dotfiles using stow
    if check_repo "$HOME/.dotfiles"; then
        print_message "$YELLOW" "Dotfiles repository exists, updating..."
        cd "$HOME/.dotfiles" || exit 1
        git pull
        check_error "Failed to update dotfiles"
        cd - > /dev/null || exit 1
    else
        setup_dotfiles "$installation_type" "${urls[4]}"
    fi
    
    cd ~ || exit 1
}
# Function to install Oh My Zsh
install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_message "$YELLOW" "Oh My Zsh is already installed, updating..."
        cd "$HOME/.oh-my-zsh" || exit 1
        git pull
        check_error "Failed to update Oh My Zsh"
        cd - > /dev/null || exit 1
    else
        print_message "$GREEN" "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        check_error "Failed to install Oh My Zsh"
    fi
}
# Function to detect screen resolution
detect_resolution() {
    local resolution
    
    # Try using xrandr first
    if command -v xrandr >/dev/null 2>&1; then
        resolution=$(xrandr | grep '*' | awk '{print $1}' | head -n 1)
    fi
    
    # If xrandr fails, try using wayland's way
    if [ -z "$resolution" ] && command -v wlr-randr >/dev/null 2>&1; then
        resolution=$(wlr-randr | grep -oP '\d+x\d+' | head -n 1)
    fi
    
    # If both fail, use default resolution
    if [ -z "$resolution" ]; then
        print_message "$YELLOW" "Could not automatically detect screen resolution. Using default 1920x1080."
        resolution="1920x1080"
    fi
    
    echo "$resolution"
}

# Function to create temporary directory
setup_workspace() {
    print_message "$GREEN" "Setting up workspace..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit 1
    
    # Clone the repository
    git clone https://github.com/OliveThePuffin/yorha-grub-theme.git
    check_error "Failed to clone Yorha GRUB theme repository"
}

# Function to cleanup temporary files
cleanup() {
    print_message "$GREEN" "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}
# Function to install theme
install_theme() {
    local resolution=$1
    local theme_folder
    
    print_message "$GREEN" "Installing Yorha GRUB theme for resolution $resolution..."
    
    # Create themes directory if it doesn't exist
    sudo mkdir -p /boot/grub/themes
    check_error "Failed to create GRUB themes directory"
    
    # Find matching theme folder
    theme_folder=$(find ./yorha-grub-theme -type d -name "*$resolution" | head -n 1)
    
    if [ -z "$theme_folder" ]; then
        print_message "$YELLOW" "No theme found for resolution $resolution. Using 1920x1080 as fallback."
        theme_folder=$(find ./yorha-grub-theme -type d -name "*1920x1080" | head -n 1)
    fi
    
    if [ -n "$theme_folder" ]; then
        # Copy theme to GRUB themes directory
        sudo cp -r "$theme_folder" /boot/grub/themes/
        check_error "Failed to copy theme files"
        
        # Get theme name and update GRUB configuration
        local theme_name=$(basename "$theme_folder")
        
        # Backup original GRUB configuration
        sudo cp /etc/default/grub /etc/default/grub.backup
        check_error "Failed to backup GRUB configuration"
        
        # Update GRUB configuration
        sudo sed -i "s|^#*GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/$theme_name/theme.txt\"|" /etc/default/grub
        check_error "Failed to update GRUB configuration"
        
        # Update GRUB
        if command -v update-grub >/dev/null 2>&1; then
            sudo update-grub
        else
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
        check_error "Failed to update GRUB"
        
        print_message "$GREEN" "GRUB theme installed successfully!"
        print_message "$YELLOW" "Original GRUB configuration backed up to /etc/default/grub.backup"
    else
        print_message "$RED" "Failed to find a suitable GRUB theme folder"
        exit 1
    fi
}


install_grub_theme() {
    local resolution=$(detect_resolution)
    print_message "$GREEN" "Detected screen resolution: $resolution"
    
    setup_workspace
    # Install theme
    install_theme "$resolution"
    
    # Cleanup
    cleanup
    
    print_message "$GREEN" "Installation completed successfully!"
    print_message "$YELLOW" "Please reboot your system to see the new GRUB theme."


}
# Main function
main() {
    check_root
    
    print_message "$GREEN" "Starting system setup..."
    
    local installation_type
    installation_type=$(get_installation_type)
    print_message "$GREEN" "installation_type: $installation_type"

    install_base_packages
    install_yay
    configure_pacman
    install_packages

    install_oh_my_zsh
    clone_repos "$installation_type"

    # Add GRUB theming step
    read -p "Would you like to install the Yorha GRUB theme? (y/n): " install_grub
    if [ "$install_grub" = "y" ]; then
        install_grub_theme
    fi

    chsh -s $(which zsh)    
    sudo chsh -s $(which zsh)  
    systemctl enable bluetooth
    print_message "$GREEN" "Setup completed successfully!"
    print_message "$YELLOW" "Please log out and back in for all changes to take effect."
    print_message "$YELLOW" "Review and adjust configurations in ~/.config as needed."
}

# Run main function
main "$@"
