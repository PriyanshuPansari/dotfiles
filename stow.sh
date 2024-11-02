# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}



setup_dotfiles() {
    print_message "$GREEN" "Setting up dotfiles with GNU Stow..."
    
    # Clone dotfiles to ~/.dotfiles instead of ~/clone/dotfiles
    cd ~ || exit 1
    
    # Clone the dotfiles repository
    
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
        "zshrc"
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
            stow -v --adopt "$package"
            print_message "$GREEN" "Stowed $package configuration"
        else
            print_message "$YELLOW" "No configuration found for $package"
        fi
    done
    cd ~/.dotfiles
    git --reset hard
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
setup_dotfiles
