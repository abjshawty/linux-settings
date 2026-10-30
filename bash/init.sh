#!/bin/bash
# Bootstrap a fresh Arch install: update the system, install CLI tools, then build the yay AUR helper.
# Omarchy already ships yay (and most of these tools), so --needed skips what is installed.
set -euo pipefail

sudo pacman -Syu
sudo pacman -S --needed git base-devel
sudo pacman -S --needed neovim docker bat eza fzf ripgrep fd zoxide tealdeer fastfetch btop starship github-cli

# Nerd Font for starship's icons; Omarchy ships the conflicting -basic variant, which also provides it
if ! pacman -Q ttf-jetbrains-mono-nerd &>/dev/null; then
  sudo pacman -S --needed ttf-jetbrains-mono-nerd
fi

if ! command -v rustup &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

if [[ ! -d "$HOME/.nvm" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi
# nvm.sh trips over set -u
set +u
source "$HOME/.nvm/nvm.sh"
nvm install --lts
set -u

if ! command -v yay &>/dev/null; then
  build_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg -si)
  rm -rf "$build_dir"
fi

sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"

tldr --update
