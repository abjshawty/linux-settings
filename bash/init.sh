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

# The curl installers' bin dirs may not be on PATH until a new shell, so check the files too
if ! command -v rustup &>/dev/null && [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi
# nvm isn't safe under set -euo pipefail, so run it in a clean shell
bash -c 'source "$HOME/.nvm/nvm.sh" && nvm install --lts'

if ! command -v claude &>/dev/null && [[ ! -x "$HOME/.local/bin/claude" ]]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

if ! command -v yay &>/dev/null; then
  build_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg -si)
  rm -rf "$build_dir"
fi

sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"
tldr --update

# Append a line to ~/.bashrc unless it's already there
add_to_bashrc() {
  grep -qsxF "$1" "$HOME/.bashrc" || echo "$1" >> "$HOME/.bashrc"
}

add_to_bashrc 'export PATH="$HOME/.local/bin:$PATH"'
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
add_to_bashrc "source \"$script_dir/profile.sh\""

mkdir -p "$HOME/.config"
touch "$HOME/.config/starship.toml"

sudo pacman -S --needed ufw tailscale
sudo systemctl enable --now tailscaled.service

# Remove this rule if ssh should only be reachable over the tailnet
sudo ufw allow ssh
# ufw accepts rules for interfaces that don't exist yet, so this works before tailscale up
sudo ufw allow in on tailscale0
# The ssh rule keeps remote sessions reachable, so enabling here can't lock you out
if ! sudo ufw status | grep -q '^Status: active'; then
  sudo ufw --force enable
fi
sudo systemctl enable ufw.service

if ! tailscale status &>/dev/null; then
  echo "Tailscale isn't logged in: run 'sudo tailscale up' to authenticate."
fi
