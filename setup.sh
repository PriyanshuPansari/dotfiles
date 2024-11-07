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

# Source the configuration files
for config in "packages.conf" "repos.conf"; do
    if [ -f "$config" ]; then
        source "$config"
    else
        print_message "$RED" "$config not found!"
        exit 1
    fi
done


configure_pacman() {
    pacman_conf="/etc/pacman.conf"

    lines_to_edit=(
        "Color"
        "CheckSpace"
        "VerbosePkgLists"
        "ParallelDownloads"
    )
    
    for line in "${lines_to_edit[@]}"; do
        if grep -i "^#$line" "$pacman_conf"; then
            sudo sed -i "s/^#$line/$line/" "$pacman_conf"
        fi
    done
    
    if grep -q "^ParallelDownloads" "$pacman_conf" && ! grep -q "^ILoveCandy" "$pacman_conf"; then
        sudo sed -i "/^ParallelDownloads/a ILoveCandy" "$pacman_conf"
    fi

    sudo pacman -Sy
}

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
    
    # Remove specified packages first
    if [ ${#REMOVE_PACKAGES[@]} -gt 0 ]; then
        yay -R "${REMOVE_PACKAGES[@]}"
    fi
    
    # Install hyprutils-git with force yes
    yay -S --noconfirm hyprutils-git
    
    # Install main packages
    yay -S --noconfirm "${PACKAGES[@]}"
    check_error "Failed to install additional packages"

    # Install audio packages based on selection
    case "$AUDIO_SYSTEM" in
        "pipewire")
            print_message "$GREEN" "Installing PipeWire audio system..."
            yay -S --noconfirm "${PIPEWIRE_PACKAGES[@]}"
            check_error "Failed to install PipeWire packages"
            
            # Enable PipeWire services
            systemctl --user enable pipewire.service
            systemctl --user enable pipewire-pulse.service
            systemctl --user enable wireplumber.service
            ;;
        "pulseaudio")
            print_message "$GREEN" "Installing PulseAudio audio system..."
            yay -S --noconfirm "${PULSEAUDIO_PACKAGES[@]}"
            check_error "Failed to install PulseAudio packages"
            
            # Enable PulseAudio service
            systemctl --user enable pulseaudio.service
            ;;
    esac

    # Install gaming packages if selected
    if [ "$INSTALL_GAMING" = true ]; then
        print_message "$GREEN" "Installing gaming packages..."
        yay -S --noconfirm "${GAMING_PACKAGES[@]}"
        check_error "Failed to install gaming packages"
    fi

    # Install bluetooth packages if selected
    if [ "$INSTALL_BLUETOOTH" = true ]; then
        print_message "$GREEN" "Installing Bluetooth packages..."
        yay -S --noconfirm "${BLUETOOTH_PACKAGES[@]}"
        check_error "Failed to install Bluetooth packages"
    fi
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
    
    # Use STOW_PACKAGES from repos.conf instead of hardcoded array
    for package in "${STOW_PACKAGES[@]}"; do
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
    
    # Stow each package using the configuration from repos.conf
    print_message "$GREEN" "Stowing configuration packages..."
    for package in "${STOW_PACKAGES[@]}"; do
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
    
    # Use repository URLs from repos.conf
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

# Function to install Nvidia drivers and configure system
install_nvidia() {
    print_message "$GREEN" "Installing Nvidia packages and configuring system..."
    
    # Install Nvidia packages for each kernel
    for krnl in $(cat /usr/lib/modules/*/pkgbase); do
        for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
            yay -S --noconfirm "$NVIDIA"
            check_error "Failed to install $NVIDIA"
        done
    done

    # Configure mkinitcpio
    if ! grep -qE '^MODULES=.*nvidia.*nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
        sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        print_message "$GREEN" "Added Nvidia modules to mkinitcpio.conf"
    fi
    
    check_error "Failed to regenerate initramfs"

    # Configure modprobe
    local nvidia_conf="/etc/modprobe.d/nvidia.conf"
    if [ ! -f "$nvidia_conf" ]; then
        echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee "$nvidia_conf"
        check_error "Failed to create nvidia.conf"
    fi

    sudo mkinitcpio -P
    # Configure GRUB
    if [ -f /etc/default/grub ]; then
        if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
            sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' /etc/default/grub
        fi
        if ! grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
            sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' /etc/default/grub
        fi
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        check_error "Failed to update GRUB configuration"
    fi

    # Blacklist nouveau
    read -p "Would you like to blacklist nouveau? (y/n): " blacklist_choice
    if [ "$blacklist_choice" = "y" ]; then
        local nouveau_conf="/etc/modprobe.d/nouveau.conf"
        if [ ! -f "$nouveau_conf" ]; then
            echo "blacklist nouveau" | sudo tee "$nouveau_conf"
            echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf"
            print_message "$GREEN" "Nouveau has been blacklisted"
        fi
    fi
}

# Main function
main() {
    check_root
    
    print_message "$GREEN" "Starting system setup..."
    
    local installation_type
    installation_type=$(get_installation_type)
    print_message "$GREEN" "installation_type: $installation_type"

    # Ask about audio system preference
    while true; do
        read -p "Which audio system would you like to use? (pipewire/pulseaudio): " audio_choice
        case "$audio_choice" in
            pipewire|pulseaudio)
                AUDIO_SYSTEM="$audio_choice"
                break
                ;;
            *)
                print_message "$YELLOW" "Please enter either 'pipewire' or 'pulseaudio'"
                ;;
        esac
    done

    # Ask about gaming installation
    read -p "Would you like to install gaming-related packages and repositories? (y/n): " gaming_choice
    if [ "$gaming_choice" = "y" ]; then
        INSTALL_GAMING=true
        # Enable multilib if not already enabled
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            print_message "$GREEN" "Enabling multilib repository..."
            echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
            sudo pacman -Sy
        fi
    fi

    # Ask about Bluetooth installation
    read -p "Would you like to install Bluetooth support? (y/n): " bluetooth_choice
    if [ "$bluetooth_choice" = "y" ]; then
        INSTALL_BLUETOOTH=true
    fi

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

    # Ask about Nvidia installation
    read -p "Would you like to install Nvidia drivers and configure the system? (y/n): " nvidia_choice
    if [ "$nvidia_choice" = "y" ]; then
        install_nvidia
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
