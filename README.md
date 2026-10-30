# Linux settings

Setup for my Arch / Omarchy machines.

## Structure

```
linux-settings/
├── bash/
│   ├── bootstrap.sh # Fresh Arch, as root: user, sudo, SSH hardening, then init.sh
│   ├── init.sh      # Fresh Arch: update, install CLI tools, build yay if missing
│   └── profile.sh   # Bash functions and aliases
└── omarchy/
    ├── hooks/theme-set.d/  # Make Yaak and Spotify follow the Omarchy theme
    └── install-hooks.sh    # Install every hook and apply the current theme
```

## Bootstrap

On a brand-new Arch install with only root, fetch and run the bootstrap (git isn't installed yet, but curl is):

```sh
curl -fsSLO https://raw.githubusercontent.com/abjshawty/linux-settings/main/bash/bootstrap.sh
bash bootstrap.sh
```

Download it rather than piping it into bash, since `passwd` reads from stdin. It installs sudo, openssh and git; creates `abjshawty` in `wheel` and grants wheel sudo through `/etc/sudoers.d/10-wheel`; installs the SSH key; then turns off root and password login over SSH, after checking the config with `sshd -t`. Finally it clones this repo to `~/Projects/settings` as that user and runs `init.sh`. It's safe to re-run. Before closing the root session, check that `ssh abjshawty@<host>` works from another machine.

On a machine where your user already exists, run `init.sh` directly:

```sh
./bash/init.sh
```

It updates the system, then installs:

- **pacman packages:** neovim, docker, bat, eza, fzf, ripgrep, fd, zoxide, tealdeer, fastfetch, btop, starship, github-cli
- **JetBrains Mono Nerd Font** for starship's icons, skipped when Omarchy's `-basic` variant is already installed
- **rustup**, **nvm** with the latest Node LTS, and **Claude Code**, each through its official installer
- **yay**, built from the AUR if it's missing

It also enables docker, adds you to the `docker` group, downloads the tldr pages, creates an empty `~/.config/starship.toml` if there isn't one, and adds two lines to `~/.bashrc`: one putting `~/.local/bin` on PATH and one sourcing `bash/profile.sh` from wherever the repo is cloned. Log out and back in for the docker group to apply, and run `claude` once to log in. The script is safe to re-run.

### Firewall and Tailscale

`init.sh` installs **ufw** and **tailscale**, starts `tailscaled`, and adds two ufw rules: allow ssh, and allow all traffic arriving on `tailscale0`. If ufw isn't active yet, it enables it. Your ssh session survives that because the ssh rule is already in place. If ssh should only be reachable over the tailnet, delete the public rule afterwards with `sudo ufw delete allow ssh`.

If Tailscale isn't logged in, the script prints a reminder. Run `sudo tailscale up` once to authenticate.

## Bash profile

`init.sh` sources it from `~/.bashrc` for you. Open a new terminal after the first run to load it.

It sets up the starship prompt, zoxide (`cd` is aliased to `z`), and fzf keybindings (Ctrl-R history, Ctrl-T files, Alt-C directories, listed with fd).

Key functions and aliases: `connect_wifi` / `disconnect_wifi` (iwd), `find_from_port`, `find_port`, `get_ip`, `new_nodeapp`, `remove_folder [--dry-run]`, `dev` (go to `~/Projects`), `hist` (search history), `n` (nvim), `s` (fuzzy-pick a pacman package to install), and eza-backed `ls` / `ll` / `la` / `lt`.

## Omarchy hooks

`omarchy/hooks/<event>.d/` mirrors `~/.config/omarchy/hooks/`. To install them all on a machine and apply the current theme right away:

```sh
./omarchy/install-hooks.sh
```

The `theme-set` hooks need some one-time setup in each app (adding the Yaak plugin, patching Spotify with Spicetify). That's documented in the vault's *Omarchy theme sync* note.

## search

Install the [`search`](https://github.com/abjshawty/search) CLI onto PATH with:

```sh
cargo install --git ssh://git@github.com/abjshawty/search
```
