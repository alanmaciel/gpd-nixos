# gpd-nixos

Declarative NixOS configuration for a **GPD Micro PC** — a 6", 720x1280 portrait
handheld. It covers the whole machine: system configuration, a Hyprland Wayland
session, and the user dotfiles, all versioned in one repository.

Everything is written against plain NixOS channels (no flakes yet), and dotfiles
are symlinked into `~/.config` by a system activation script, so no home-manager
is required.

## Contents

```
gpd-nixos/
├── configuration.nix           # Main system configuration
├── hardware-configuration.nix  # Auto-generated hardware detection (do not edit)
├── home.nix                    # Symlinks dotfiles/* into ~/.config/*
├── CLAUDE.md                   # Notes for Claude Code
├── SETUP_SUMMARY.md            # Log of the initial cleanup/migration
└── dotfiles/
    ├── hypr/                   # Hyprland + hyprpaper
    ├── waybar/                 # Status bar (config, style.css, powermenu.sh)
    ├── alacritty/              # Terminal
    ├── rofi/                   # Application launcher
    ├── btop/                   # System monitor
    ├── gtk-3.0/, gtk-4.0/      # GTK theming
    ├── doom/                   # Doom Emacs user config (git submodule)
    └── emacs/                  # Doom Emacs framework (git submodule)
```

## What's in the stack

| Layer | Choice |
| --- | --- |
| Compositor | Hyprland (Wayland) with XWayland enabled |
| Login manager | greetd + tuigreet (TUI) |
| Bar | Waybar |
| Launcher | Rofi (Wayland build) |
| Terminal | Alacritty |
| Editor | Doom Emacs (`emacs-pgtk`) |
| File manager | PCManFM |
| Audio | PipeWire (with PulseAudio and ALSA compatibility) |
| Shell colors | Gruvbox Dark, in the TTY, terminal and bar |
| Containers | Docker, enabled on boot |

## GPD Micro PC specifics

The hardware is small and unusual, so a handful of settings exist purely for it:

- **Portrait panel.** The internal display is `DSI-1` at 720x1280. Hyprland
  rotates it with `monitor = DSI-1,720x1280@60,0x0,1.25,transform,3` — that
  single line also carries the **1.25 scale factor**. Scaling is deliberately
  set in exactly one place: `GDK_SCALE`/`QT_SCALE_FACTOR` are *not* used,
  because GTK parses `GDK_SCALE` as an integer and Qt already receives the
  scale from the compositor under Wayland (setting both multiplied the scale).
- **Text-mode GRUB.** `gfxmodeEfi`/`gfxpayloadEfi` are set to `"text"`; the
  graphical GRUB misbehaves on this panel.
- **Intel iGPU stability.** `i915.enable_psr=0` and `i915.enable_fbc=0` are
  passed on the kernel command line, plus `ucsi_acpi.disable=1`. The Gemini Lake
  iGPU uses the `intel-media-driver` (iHD) VA-API driver.
- **Quiet boot.** `quiet`, `loglevel=3`, `systemd.show_status=false` and
  `rd.udev.log_level=3` keep kernel chatter from overlapping the login screen.
- **Large console font.** `ter-u32n` from `terminus_font`, with a 16-color
  Gruvbox Dark ANSI palette for the TTY.
- **Dual-function keys.** The Micro PC keyboard is cramped, so
  interception-tools + the `dual-function-keys` plugin turn three keys into
  modifiers when held (see below).

## Dual-function keys

Configured in `/etc/dual-function-keys.yaml` (generated from
`configuration.nix`), with a 200 ms tap threshold:

| Key | Tap | Hold |
| --- | --- | --- |
| `/` | `/` | Alt |
| `\` | `\` | Super |
| `↓` | Down | Ctrl |

No `DEVICE` filter is applied, so it works on any attached keyboard.

## Hyprland keybindings

`$mod` is **Super**. Workspaces are bound to the home-row-adjacent `Y U I O P`
rather than the number row, which is awkward to reach on this keyboard.

| Binding | Action |
| --- | --- |
| `mod + Return` | Alacritty |
| `mod + b` | Chromium |
| `mod + m` | Rofi |
| `mod + Shift + f` | PCManFM |
| `mod + h/j/k/l` | Move focus left/down/up/right |
| `mod + Shift + h/j/k/l` | Move window |
| `mod + Ctrl + h/j/k/l` | Resize window |
| `mod + Space` | Cycle to next window and raise it |
| `mod + q` | Close window |
| `mod + f` | Toggle fullscreen |
| `mod + t` | Toggle floating |
| `mod + y/u/i/o/p` | Switch to workspace 1–5 |
| `mod + Shift + y/u/i/o/p` | Move window to workspace 1–5 |
| `mod + Ctrl + r` | Reload Hyprland config |
| `mod + Ctrl + q` | Exit Hyprland |
| `Print` | Region screenshot (`grim` + `slurp` → `swappy`) |
| `mod + drag LMB / RMB` | Move / resize window with the mouse |

The GPD's Fn row is bound through `XF86` keys to `brightnessctl` (brightness),
`pamixer` (volume) and `playerctl` (media).

The touchpad uses natural scrolling, middle-click emulation (left + right at
once) and button-hold scrolling on `BTN_MIDDLE`.

## Installing on a machine

```bash
git clone --recurse-submodules git@github.com:alanmaciel/gpd-nixos.git ~/nixos-config
cd ~/nixos-config

# hardware-configuration.nix is machine-specific — regenerate it rather than
# copying the one in this repo unless you are restoring the same disk layout.
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix

sudo cp configuration.nix hardware-configuration.nix home.nix /etc/nixos/
sudo nixos-rebuild switch
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

## Everyday commands

```bash
# Rebuild and switch
sudo nixos-rebuild switch

# Try a configuration without making it the default boot entry
sudo nixos-rebuild test

# Build only, do not activate
sudo nixos-rebuild build

# Roll back to the previous generation
sudo nixos-rebuild switch --rollback
```

Packages are declared in `environment.systemPackages` in `configuration.nix`.
Search for names at <https://search.nixos.org/packages> or with
`nix-env -qaP | grep <name>`.

## How dotfiles get linked

`home.nix` defines `system.userActivationScripts.linkDotfiles`, which runs on
every `nixos-rebuild switch` and symlinks each entry of `dotfiles/` into
`~/.config/`:

`hypr`, `waybar`, `alacritty`, `btop`, `doom`, `emacs`, `gtk-3.0`, `gtk-4.0`,
`rofi`.

Two safety properties are worth knowing:

- The script exits early for any user other than `alan`, since activation
  scripts run once per user and the paths are hardcoded to that home directory.
- It only replaces links it recognises as symlinks. If a **real** file or
  directory already exists at the target (for example a populated
  `~/.config/emacs` with `.local/` build output), it is left alone and the
  script prints `Skipped: <name>` — nothing is ever `rm -rf`'d.

So to change a user config: edit the file under `dotfiles/`, then restart the
affected application. A rebuild is only needed the first time, to create the
link.

## Emacs

`dotfiles/doom` (the user config) and `dotfiles/emacs` (the Doom framework) are
git submodules with their own upstreams — **commit changes to them separately**
before committing the pointer bump here.

The user config is literate: `dotfiles/doom/config.org` is the source of truth
and tangles to `config.el`. Saving `config.org` in Emacs auto-tangles and calls
`doom/reload`, so `config.el` should never be edited by hand. After editing
`init.el` or `packages.el`, run `doom sync` and restart Emacs.

`configuration.nix` supplies the native dependencies Doom expects — `gcc`,
`cmake`, `gnumake` and `libtool` for vterm and native compilation, `nodejs` for
the LSP servers, `ripgrep`/`fd` for search, `pandoc`, `graphviz`, plus the
language toolchains and formatters (`python3Full`, `ruby`, `shellcheck`,
`html-tidy`, `stylelint`, `js-beautify`, `isort`, `pytest`).

One detail worth noting: `pdf-tools` needs an `epdfinfo` helper binary that
Emacs would otherwise try to compile inside `~/.config/emacs`. The config
instead builds a tiny derivation that symlinks the nixpkgs-provided binary into
`bin/`, and `config.org` picks it up with `executable-find` so no store path is
hardcoded.

## Networking and services

- **SSH** is enabled on port 22 with password authentication;
  `PermitRootLogin = "prohibit-password"` and `UseDns = false` (reverse lookups
  add login latency when DNS can't resolve the source address).
- **Firewall** opens TCP and UDP `53317` for LocalSend (transfer and multicast
  discovery respectively). Port 22 is opened by the openssh module itself.
- **xdg-portal** uses only `xdg-desktop-portal-hyprland`; the GTK portal is
  deliberately excluded because it introduces long delays.

## Store housekeeping

GRUB keeps 10 menu entries, but that does not delete generations — so garbage
collection is automatic:

```nix
nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 30d"; };
nix.optimise.automatic = true;   # hard-link identical store files
```

Manually, if you need space now:

```bash
sudo nix-collect-garbage -d                      # everything but the current gen
sudo nix-collect-garbage --delete-older-than 30d
```

## State version

`system.stateVersion = "24.11"`. This records the NixOS release the system was
installed with, not the release it currently tracks. **Do not change it** — it
selects stateful-data compatibility behaviour for services like databases.

## Notes

- `hardware-configuration.nix` is generated by `nixos-generate-config`; it holds
  this machine's filesystem UUIDs and should not be hand-edited.
- `.gitignore` excludes browser caches, the Doom `.local/` build output, binary
  dconf/akonadi databases and machine-local KDE state.
- `SETUP_SUMMARY.md` documents the one-time migration that brought all of this
  into a single repository.
