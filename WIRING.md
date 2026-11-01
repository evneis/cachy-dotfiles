# Wiring these dotfiles on a new system

This is the post-install checklist for applying this repository to an
**already-installed** Arch-based system. It covers the five XDG config
directories, the SDDM login theme, wallpapers, services, and the per-machine
edits that cannot be copied from the reference machine.

For installing CachyOS itself (partitioning, NVIDIA, Limine, Secure Boot), see
[CACHYOS_SETUP.md](CACHYOS_SETUP.md). For the package list and repository
layout, see [README.md](README.md).

## Quick path

1. [Install packages](#1-install-packages) (official repos + AUR).
2. [Clone the repository](#2-clone-the-repository) to `~/Projects/Dotfiles`.
3. [Back up existing configs and symlink](#3-back-up-existing-configs-and-create-symlinks)
   the five config directories.
4. [Copy the wallpapers](#4-install-wallpapers) to `~/Pictures/wallpapers`.
5. [Edit the per-machine values](#5-per-machine-edits): username paths,
   monitors, mouse, Waybar sensors, and optional services.
6. [Enable services](#6-enable-services) and [log in and verify](#7-first-login-and-verification).

## What this repository manages

| Repository path | Installed as | Notes |
|---|---|---|
| `hypr/` | `~/.config/hypr` (symlink) | Hyprland 0.56+ Lua config; `*.conf.x` are disabled legacy backups |
| `waybar/` | `~/.config/waybar` (symlink) | Bar config, CSS, layouts, and the power-profile script |
| `wlogout/` | `~/.config/wlogout` (symlink) | Session/power menu |
| `yazi/` | `~/.config/yazi` (symlink) | File manager config, keymap, and vendored plugin |
| `fastfetch/` | `~/.config/fastfetch` (symlink) | System-info config and logo |
| `usr/share/sddm/themes/silent/` | `/usr/share/sddm/themes/silent/` (copy) | System path, so it is copied rather than symlinked |
| `images/wallpapers/` | `~/Pictures/wallpapers/` (copy) | Referenced by `hyprpaper.conf` and `hyprlock.conf` |
| `packages/` | not installed | Reference snapshot and `generate.sh` |

This repository does **not** manage shell, Git, editor, terminal-emulator, or
browser-profile dotfiles. Only the application configs above are wired.

## Before you start

- Arch-based distribution (Arch, CachyOS, EndeavourOS, …) with systemd and
  Wayland.
- **Hyprland 0.56 or newer** for the Lua config. Check with `hyprctl version`.
- A regular user account with `sudo`. The reference machine uses `evan`; if your
  username differs, follow [Home directory paths](#home-directory-paths).
- Network access and an AUR helper (`yay` is assumed below).
- Back up anything in `~/.config` that you want to keep. The symlink step moves
  existing configs into a timestamped backup directory.

---

## 1. Install packages

### Minimal set (recommended for a clean Arch/CachyOS install)

Install the official-repository packages:

```bash
sudo pacman -S --needed \
  base-devel git \
  hyprland hyprpaper hyprlock \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  waybar pipewire pipewire-pulse wireplumber playerctl pacman-contrib \
  wlogout libnotify kitty btop fastfetch yazi rofi dolphin \
  networkmanager network-manager-applet swaync grim slurp wl-clipboard \
  brightnessctl power-profiles-daemon qt6ct gnome-settings-daemon fish \
  vlc imv tdf neovim sddm qt6-svg qt6-virtualkeyboard qt6-multimedia \
  qt6-multimedia-ffmpeg qt6-imageformats
```

Install the AUR packages:

```bash
yay -S --needed walker-bin elephant-all zen-browser-bin \
  ttf-jetbrains-mono-nerd
```

Package-name notes:

- On CachyOS, `walker`, `elephant`, and `zen-browser-bin` may be available from
  the CachyOS repositories under those names. Use whichever name your enabled
  repositories provide.
- `tdf` is the PDF opener used by Yazi. It is in `extra` on current Arch.
- `fish` is used by Waybar's on-click commands and by the Yazi opener.
- `qt6ct` and `gnome-settings-daemon` are referenced by Hyprland's environment
  and `gsettings` call. They are not required for the compositor to start.
- `dolphin` and `rofi` are listed because the configs reference them, but the
  active keybinds open Yazi and Walker instead. Install them only if you
  re-enable the corresponding binds.

Optional applications that have keybinds in `hypr/keybinds.lua`:

```bash
yay -S --needed obsidian cursor-bin vesktop
```

`packages/cider.txt` is optional and comes from a third-party repository; see
the Cider section of [README.md](README.md).

### Exact snapshot (only for an identical CachyOS install)

`packages/pacman.txt` and `packages/aur.txt` are a full snapshot of the
reference CachyOS machine. They include CachyOS-only packages and unrelated
applications. Do **not** blindly install them on vanilla Arch.

On an identical CachyOS install:

```bash
sudo pacman -S --needed - < packages/pacman.txt
yay -S --needed - < packages/aur.txt
```

Kernel, kernel-header, and NVIDIA driver packages are intentionally excluded;
install the ones that match the target hardware. See
[CACHYOS_SETUP.md](CACHYOS_SETUP.md).

### Verify the important binaries

```bash
for b in Hyprland hyprctl hyprpaper hyprlock waybar wlogout yazi fastfetch \
         kitty fish walker elephant zen-browser nm-applet swaync \
         powerprofilesctl playerctl checkupdates yay grim slurp wl-copy \
         brightnessctl wpctl; do
  command -v "$b" >/dev/null || echo "missing: $b"
done
```

Resolve every `missing:` line before continuing. Some binaries come from
packages with different names (`nm-applet` → `network-manager-applet`,
`wpctl` → `wireplumber`, `checkupdates` → `pacman-contrib`).

---

## 2. Clone the repository

```bash
mkdir -p ~/Projects
git clone https://github.com/evneis/cachy-dotfiles.git ~/Projects/Dotfiles
cd ~/Projects/Dotfiles
```

If `~/Projects/Dotfiles` already exists, do not clone over it:

```bash
git -C ~/Projects/Dotfiles status
git -C ~/Projects/Dotfiles pull --ff-only
```

Do not pull if `git status` shows local work you have not reviewed.

---

## 3. Back up existing configs and create symlinks

Run this block as your normal user, **not** with `sudo`. It moves only the five
config directories managed by this repository and leaves a timestamped backup:

```bash
bash <<'EOF'
set -eu
repo="$HOME/Projects/Dotfiles"
backup="$HOME/.config/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$HOME/.config" "$backup"

for name in hypr waybar wlogout yazi fastfetch; do
    target="$HOME/.config/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "$backup/$name"
    fi
    ln -s "$repo/$name" "$target"
done

printf 'Previous configs: %s\n' "$backup"
EOF
```

Confirm every link points into the repository:

```bash
readlink -f ~/.config/{hypr,waybar,wlogout,yazi,fastfetch}
```

Each result should begin with `/home/<you>/Projects/Dotfiles/`.

> **Symlink the whole directory, not individual files.** `hyprland.lua` loads
> `keybinds.lua` with `require("keybinds")`, and Waybar/Yazi expect their
> supporting files beside the main config.

### Hyprland 0.56+ and the Lua config

`hypr/hyprland.lua` is the active Hyprland config, and `hypr/keybinds.lua` is
loaded from it. Hyprland 0.56+ automatically prefers `hyprland.lua` over
`hyprland.conf`.

The files ending in `.conf.x` are disabled legacy backups. Hyprland ignores
them. If you are stuck on Hyprland older than 0.56, you can fall back to the
legacy config:

```bash
cd ~/.config/hypr
mv hyprland.lua hyprland.lua.disabled
mv hyprland.conf.x hyprland.conf
mv keybinds.conf.x keybinds.conf
```

The Lua config is the maintained one, so prefer upgrading Hyprland instead.

---

## 4. Install wallpapers

The configs expect wallpapers in `~/Pictures/wallpapers`:

```bash
mkdir -p ~/Pictures/wallpapers
cp ~/Projects/Dotfiles/images/wallpapers/*.jpg ~/Pictures/wallpapers/
```

Current references:

| File | Wallpaper |
|---|---|
| `hypr/hyprpaper.conf` | `~/Pictures/wallpapers/desertcity.jpg` |
| `hypr/hyprlock.conf` | `~/Pictures/wallpapers/gr86_road.jpg` |

To use different images, copy them in and edit those two files. If your
username is not `evan`, also follow the next section.

---

## 5. Per-machine edits

These values are specific to the reference machine. Edit the files in
`~/Projects/Dotfiles`; the symlinks make the edits live.

### Home directory paths

The configs contain hard-coded `/home/evan` paths. If your username is `evan`,
skip this. Otherwise, replace them:

```bash
grep -RIl '/home/evan' ~/Projects/Dotfiles/{hypr,waybar,wlogout,yazi,fastfetch} \
  | while read -r f; do
      sed -i "s|/home/evan|$HOME|g" "$f"
    done
```

Affected files include `hypr/keybinds.lua`, `hypr/hyprpaper.conf`,
`hypr/hyprlock.conf`, and `waybar/config.jsonc`. Verify:

```bash
grep -RIn '/home/evan' ~/.config/{hypr,waybar,wlogout,yazi,fastfetch}
```

The command should print nothing.

### Monitors

List the connected outputs from inside a Hyprland session:

```bash
hyprctl monitors all
```

Edit the two `hl.monitor({ ... })` blocks at the top of
`hypr/hyprland.lua` (currently `eDP-1` and `HDMI-A-1`). Use your connector
names, modes, positions, and scales.

If the display is unusable, replace both blocks with the safe fallback:

```lua
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
```

Then reload:

```bash
hyprctl reload
```

### Mouse

The config applies a sensitivity override to a specific mouse:

```lua
hl.device({
    name = "logitech-g502-hero-gaming-mouse",
    sensitivity = -0.5,
})
```

Find your device name:

```bash
hyprctl devices
```

Change the name, adjust `sensitivity`, or remove the block entirely.

### Keyboard layout

In `hypr/hyprland.lua`, the `input` block sets:

```lua
kb_layout = "us",
```

Change it to your layout (for example `"de"` or `"us,de"`).

### Programs

The programs used by the keybinds are globals at the top of
`hypr/hyprland.lua`:

```lua
terminal = "kitty"
fileManager = "dolphin"
menu = "walker"
browser = "zen-browser"
```

`keybinds.lua` reads these globals. Change them here rather than editing each
bind.

### Waybar

Edit `waybar/config.jsonc`:

- **Temperature**: the `temperature` module assumes thermal zone `2` and
  `/sys/class/hwmon/hwmon2/temp1_input`. Find the correct device with:

  ```bash
  for h in /sys/class/hwmon/hwmon*; do
    printf '%s %s\n' "$h" "$(cat "$h/name" 2>/dev/null)"
  done
  ```

  Update `thermal-zone` and `hwmon-path`, or remove `temperature` from
  `group/hollow-right-1` and delete its module block.

- **Battery**: on a desktop, remove `battery` from `group/hollow-left-5` and
  delete its module block; otherwise the module stays empty.
- **AUR helper**: `custom/pkg-aur` runs `yay -Qua`. Change it to `paru -Qua`
  (or your helper) if needed.
- **Updates**: `custom/pacman` uses `checkupdates` from `pacman-contrib`.
- **Power profile**: `custom/powerprofile` runs
  `~/.config/waybar/scripts/powerprofile` and requires
  `power-profiles-daemon`.
- **Audio**: the `wireplumber` module requires PipeWire/WirePlumber.
- **Media**: `mpris` and the previous/pause/next buttons require `playerctl`.
- **Notifications**: `custom/notification-center` requires `swaync`.
- **Font**: `style.css` expects `JetBrainsMono Nerd Font`.
- **Network**: the active layout does not include a network module, so no
  rofi/Wi-Fi script is required unless you add one.

Restart Waybar after config changes:

```bash
pkill waybar; waybar &
```

### wlogout

`wlogout/layout` includes a **Hibernate** action. If hibernation is not
configured on this machine, remove the object with `"label": "hibernate"` from
the file. The lock action runs `hyprlock`; the rest use `systemctl` /
`loginctl`.

### Yazi

The `what-size` plugin is vendored under `yazi/plugins/what-size.yazi`, so it
works through the symlink. If the plugin is missing, install the declared
packages from the config directory:

```bash
cd ~/.config/yazi
ya pkg install
```

Yazi's openers use:

| Action | Command |
|---|---|
| Edit | `kitty fish -c "nvim %s"` |
| Play | `vlc %s` |
| Image | `imv %s` |
| PDF | `tdf %s` |

The `y` key copies file URIs with `wl-copy`, so `wl-clipboard` is required.
`Ctrl+T` opens Kitty in the current directory.

### Fastfetch

The logo is included at `fastfetch/logo.png`, and the config references
`~/.config/fastfetch/logo.png`. No action is needed. The config uses
`"type": "kitty"`; if you use a different terminal, change the logo type or
remove the logo block.

### SDDM Silent theme

The repository vendors the Silent theme. Copy only that theme — not the whole
`usr/share/sddm` tree:

```bash
sudo install -d /usr/share/sddm/themes/silent
sudo cp -a ~/Projects/Dotfiles/usr/share/sddm/themes/silent/. \
  /usr/share/sddm/themes/silent/
```

Create or edit `/etc/sddm.conf` (or a drop-in under `/etc/sddm.conf.d/`):

```ini
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
```

Test the greeter before rebooting:

```bash
cd /usr/share/sddm/themes/silent
./test.sh
```

The test is intentionally not a usable login session. Close it after confirming
that the theme renders. If it fails, restore the previous theme in
`/etc/sddm.conf`; do not reboot into a broken greeter.

Notes:

- The theme's default preset requests `RedHatDisplay`. Missing that font
  changes typography but should not prevent login. Change `font-family` in
  `configs/default.conf` if needed.
- The theme needs `qt6-svg`, `qt6-virtualkeyboard`, `qt6-multimedia`,
  `qt6-multimedia-ffmpeg`, and `qt6-imageformats`.
- The repository also contains the stock `elarun`, `maldives`, and `maya`
  themes. Do not copy them unless you want them.
- Optional avatar: copy the vendored face icon to SDDM's per-user path:

  ```bash
  sudo cp ~/Projects/Dotfiles/usr/share/sddm/faces/.face.icon \
    "/usr/share/sddm/faces/$USER.face.icon"
  ```

- Alternatively, install `sddm-silent-theme` from the AUR instead of copying
  the vendored theme. Do not do both.

---

## 6. Enable services

```bash
sudo systemctl enable NetworkManager sddm power-profiles-daemon
systemctl --user enable --now pipewire.socket pipewire-pulse.socket
```

If another display manager is enabled, disable it first (for example
`sudo systemctl disable gdm`). WirePlumber normally starts as a user service
when PipeWire needs it; confirm with:

```bash
systemctl --user --no-pager status pipewire wireplumber
wpctl status
```

Waybar, Hyprpaper, SwayNC, Walker, Elephant, and `nm-applet` are started by
Hyprland's autostart block, not by systemd.

---

## 7. First login and verification

Log in to the **Hyprland** Wayland session. Then run:

```bash
hyprctl configerrors
hyprctl monitors all
hyprctl devices
systemctl --no-pager --failed
systemctl --user --no-pager --failed
wpctl status
```

`hyprctl configerrors` should print nothing. Resolve every reported parse
error before continuing.

Check these interactions:

- Waybar appears and its modules populate.
- `Super+Return` opens Kitty.
- `Super+Space` opens Walker.
- `Super+L` opens Hyprlock with the correct wallpaper.
- `Super+Shift+S` captures a region to the clipboard.
- `Super+Escape` opens wlogout.
- `Super+X` cycles the power profile.
- Yazi previews files; images open in `imv`, video in VLC, PDFs in `tdf`, and
  text in Neovim.
- `fastfetch` renders the logo in Kitty.
- SDDM renders the Silent theme and starts the Hyprland session.

Useful diagnostics:

```bash
hyprctl version
hyprctl getoption general:layout
pgrep -a waybar
pgrep -a hyprpaper
fc-list | grep -i 'JetBrainsMono Nerd'
```

---

## 8. Updating and rollback

### Update

```bash
git -C ~/Projects/Dotfiles pull --ff-only
hyprctl reload
```

Reload Hyprland after Lua changes. Restart Waybar after bar config changes:

```bash
pkill waybar; waybar &
```

Yazi picks up config changes on restart.

### Rollback the symlinks

The symlink step prints the backup directory, for example
`~/.config/dotfiles-backup-20261101-183000`. To restore it:

```bash
backup="$HOME/.config/dotfiles-backup-YYYYmmdd-HHMMSS"

for name in hypr waybar wlogout yazi fastfetch; do
    if [ -L "$HOME/.config/$name" ]; then
        rm "$HOME/.config/$name"
    fi
    if [ -e "$backup/$name" ] || [ -L "$backup/$name" ]; then
        mv "$backup/$name" "$HOME/.config/$name"
    fi
done
```

The loop only removes symlinks. If a real directory is present at a target
path, `mv` fails rather than overwriting it; inspect that directory before
deleting anything.

System-level changes are not covered by that backup. Restore `/etc/sddm.conf`
and remove `/usr/share/sddm/themes/silent` manually if you want to undo the
SDDM setup.

---

## 9. Troubleshooting

### Hyprland starts with a legacy config or emergency mode

- Confirm the version: `hyprctl version` should report 0.56 or newer.
- Confirm `~/.config/hypr/hyprland.lua` exists. `*.conf.x` files are ignored.
- Check `hyprctl configerrors`.
- A Lua error can put Hyprland into emergency mode with `Super+Q` as the only
  working bind. Fix `hyprland.lua`, then run `hyprctl reload` or reboot.
- Do not keep both `hyprland.lua` and a legacy `hyprland.conf` active unless
  you understand which one Hyprland will load.

### Blank or unusable display

Switch to a TTY with `Ctrl+Alt+F3`, log in, and replace the monitor blocks in
`~/Projects/Dotfiles/hypr/hyprland.lua` with the fallback shown in
[Monitors](#monitors). Return to the session or reboot, run
`hyprctl monitors all`, and configure the exact outputs.

### Waybar is missing or blank

Run it in a terminal to see the error:

```bash
pkill waybar
waybar
```

Common causes:

- Missing Nerd Font; check with `fc-list | grep -i 'JetBrainsMono Nerd'`.
- Invalid JSONC (Waybar accepts comments and trailing commas, but not arbitrary
  syntax).
- A module's helper binary is missing; the module may simply render empty.
- The bar is on another output; check `hyprctl monitors all` and Waybar's
  `output` settings.

### Temperature or battery module is empty

The thermal zone/hwmon path is machine-specific, and desktops have no battery.
Update `thermal-zone` and `hwmon-path`, or remove the module as described in
[Waybar](#waybar).

### SDDM is blank

Switch to a TTY, restore a working theme in `/etc/sddm.conf`, and restart SDDM:

```bash
sudoedit /etc/sddm.conf
sudo systemctl restart sddm
```

Set `Current=` to the previously working theme or remove the line temporarily.
Run the theme's `./test.sh` before rebooting again.

### Wallpaper is not showing

- Confirm the image exists at the path in `hypr/hyprpaper.conf` and
  `hypr/hyprlock.conf`.
- Confirm `hyprpaper` is running: `pgrep -a hyprpaper`.
- Restart it after editing: `pkill hyprpaper; hyprpaper &`.

### A keybind opens nothing

- Confirm the program exists: for example `command -v walker`.
- The optional binds for Obsidian, Cursor, and Vesktop do nothing until those
  applications are installed.
- Check the bind in `hypr/keybinds.lua` and the program globals in
  `hypr/hyprland.lua`.
- Reload after edits: `hyprctl reload`.

### Wrong user paths

Search for leftovers:

```bash
grep -RIn '/home/evan' ~/.config/{hypr,waybar,wlogout,yazi,fastfetch}
```

Replace them using the command in [Home directory paths](#home-directory-paths),
then reload Hyprland and restart Waybar.

### NVIDIA problems

Do not guess a driver branch or copy package names from another machine. See
the NVIDIA sections of [CACHYOS_SETUP.md](CACHYOS_SETUP.md) and use CachyOS's
`chwd` on CachyOS.

---

## Related documentation

- [README.md](README.md) — package list, repository layout, and package
  snapshot details.
- [CACHYOS_SETUP.md](CACHYOS_SETUP.md) — full CachyOS installation, dual-boot,
  NVIDIA, Limine, and Secure Boot.
- [waybar/dependency.md](waybar/dependency.md) — module-level Waybar
  dependencies.
- `usr/share/sddm/themes/silent/README.md` — upstream Silent theme
  documentation.
