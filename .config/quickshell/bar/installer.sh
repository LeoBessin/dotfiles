#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}::${NC} $*"; }
success() { echo -e "${GREEN}::${NC} $*"; }
warn()    { echo -e "${YELLOW}:: WARNING:${NC} $*"; }
error()   { echo -e "${RED}:: ERROR:${NC} $*" >&2; }

# ─── Packages ───
# Pacman packages
PACMAN_PKGS=(
  hyprland
  qt6-base
  qt6-declarative
  qt6-wayland
  qt6-5compat
  qt6-multimedia
  qt6-shadertools
  qt6-svg
  qt6-quicktimeline
  networkmanager
  bluez
  bluez-utils
  cliphist
  imagemagick
  matugen
  playerctl
  brightnessctl
  jq
  starship
  fish
  ttf-material-symbols-variable-git
  ttf-twemoji
)

# AUR packages
AUR_PKGS=(
  quickshell
)

# Fonts
FONT_PKGS=(
  ttf-cascadia-code-nerd
  inter-font
  ttf-jetbrains-mono
)

# ─── Helpers ───
check_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    error "This installer is intended for Arch Linux only."
    exit 1
  fi
}

detect_aur_helper() {
  for helper in paru yay; do
    if command -v "$helper" &>/dev/null; then
      echo "$helper"
      return
    fi
  done
  echo ""
}

install_aur_helper() {
  warn "No AUR helper found. Installing paru..."
  local tmp
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

# ─── Install Steps ───
install_pacman_packages() {
  info "Installing pacman packages..."
  sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}" "${FONT_PKGS[@]}"
  success "Pacman packages installed."
}

install_aur_packages() {
  local aur
  aur=$(detect_aur_helper)

  if [[ -z "$aur" ]]; then
    install_aur_helper
    aur=$(detect_aur_helper)
  fi

  if [[ -z "$aur" ]]; then
    error "Failed to find or install an AUR helper."
    exit 1
  fi

  info "Using AUR helper: $aur"
  info "Installing AUR packages..."
  "$aur" -S --needed --noconfirm "${AUR_PKGS[@]}"
  success "AUR packages installed."
}

enable_services() {
  info "Enabling services..."
  sudo systemctl enable --now NetworkManager
  sudo systemctl enable --now bluetooth
  success "Services enabled."
}

install_config() {
  local config_src
  config_src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local config_dst="$HOME/.config/quickshell/bar"

  if [[ "$config_src" != "$config_dst" ]]; then
    info "Copying bar config to $config_dst..."
    mkdir -p "$config_dst"
    rsync -av --exclude='installer.sh' "$config_src/" "$config_dst/"
    success "Config installed."
  else
    info "Config already in place at $config_dst."
  fi
}

# ─── Main ───
main() {
  info "Starting quickshell bar installer..."
  check_arch
  install_pacman_packages
  install_aur_packages
  enable_services
  install_config
  success "Installation complete. Restart your session or launch quickshell to apply."
}

main "$@"
