#!/usr/bin/env bash
# Bootstrap a fresh Arch install: user, sudo, SSH hardening, settings repo.
# Run as root on the new machine (curl ships with pacman, git doesn't):
#   curl -fsSLO https://raw.githubusercontent.com/abjshawty/linux-settings/main/bash/bootstrap.sh
#   bash bootstrap.sh
# Not `curl | bash`: passwd would read the script itself as the password.
# Safe to re-run: every step checks before it changes anything.
set -euo pipefail

USER_NAME="abjshawty"
PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWsv9hs5cOPtkkBPSiMUWWXJMLDvZQFo9wVvnA3XlEI abjshawty@reze"
SETTINGS_REPO="https://github.com/abjshawty/linux-settings"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (the user doesn't exist yet)."

# --- Packages --------------------------------------------------------------
log "Installing base packages"
pacman -Syu --needed --noconfirm sudo openssh git

# --- User ------------------------------------------------------------------
if id "$USER_NAME" &>/dev/null; then
    log "User $USER_NAME exists"
else
    log "Creating user $USER_NAME"
    useradd -m -G wheel -s /bin/bash "$USER_NAME"
fi
usermod -aG wheel "$USER_NAME"

# passwd -S prints "P" in field 2 when a usable password is set
if [[ $(passwd -S "$USER_NAME" | awk '{print $2}') != "P" ]]; then
    log "Set a password for $USER_NAME (needed for sudo)"
    passwd "$USER_NAME"
fi

# --- sudo for wheel --------------------------------------------------------
# A drop-in instead of uncommenting /etc/sudoers: survives sudo package updates.
SUDOERS_FILE=/etc/sudoers.d/10-wheel
if [[ ! -f $SUDOERS_FILE ]]; then
    log "Granting sudo to wheel"
    tmp=$(mktemp)
    echo '%wheel ALL=(ALL:ALL) ALL' > "$tmp"
    visudo -cf "$tmp" >/dev/null || die "sudoers drop-in failed validation"
    install -m 0440 -o root -g root "$tmp" "$SUDOERS_FILE"
    rm -f "$tmp"
fi

# --- SSH key (before disabling passwords, or we lock ourselves out) --------
log "Installing SSH key"
home=$(getent passwd "$USER_NAME" | cut -d: -f6)
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "$home/.ssh"
auth="$home/.ssh/authorized_keys"
touch "$auth"
grep -qxF "$PUBKEY" "$auth" || echo "$PUBKEY" >> "$auth"
chown "$USER_NAME:$USER_NAME" "$auth"
chmod 600 "$auth"

# --- sshd hardening --------------------------------------------------------
SSHD_DROPIN=/etc/ssh/sshd_config.d/10-hardening.conf
desired=$'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no'
if [[ ! -f $SSHD_DROPIN ]] || [[ $(<"$SSHD_DROPIN") != "$desired" ]]; then
    log "Hardening sshd"
    # Arch's sshd_config ships the Include line; add it if a custom one dropped it
    grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config \
        || sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
    printf '%s\n' "$desired" > "$SSHD_DROPIN"
fi
sshd -t || die "sshd config invalid — not restarting"
systemctl enable sshd
systemctl reload-or-restart sshd

# --- Settings repo, as the user --------------------------------------------
log "Cloning settings and running init as $USER_NAME"
runuser -u "$USER_NAME" -- bash -lc "
    set -euo pipefail
    mkdir -p ~/Projects ~/Work
    if [[ -d ~/Projects/settings/.git ]]; then
        git -C ~/Projects/settings pull --ff-only
    else
        git clone '$SETTINGS_REPO' ~/Projects/settings
    fi
    cd ~/Projects/settings
    bash bash/init.sh
"

log "Done. From another machine, test before closing this session:  ssh $USER_NAME@$(hostname)"
