#!/bin/bash
# Bootstrap a fresh Arch install: update the system, install CLI tools, then build the yay AUR helper.
# Omarchy already ships yay (and most of these tools), so --needed skips what is installed.
set -euo pipefail

sudo pacman -Syu
sudo pacman -S --needed git base-devel
sudo pacman -S --needed neovim docker bat eza fzf ripgrep fd zoxide tealdeer fastfetch btop

if ! command -v yay &>/dev/null; then
  build_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg -si)
  rm -rf "$build_dir"
fi

sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"

tldr --update
