# Waybar dependency guide

This document lists the packages and tools used by this Waybar config. Install what you need for the modules you use.

## Core

| Package | Purpose |
|--------|--------|
| **waybar** | The bar itself |
| **Hyprland** | `hyprland/workspaces` and `hyprland/window` (only if you use Hyprland; replace or remove these modules on other compositors) |

## Audio

| Package | Purpose |
|--------|--------|
| **wireplumber** | Audio control (volume, mute). Used by the `wireplumber` module. Works with PipeWire. |

## Media control (MPRIS)

| Package | Purpose |
|--------|--------|
| **playerctl** | Media control for `mpris`, `custom/previous`, `custom/pause`, `custom/next` (e.g. Spotify, YouTube Music). |

## System updates (Arch)

| Package | Purpose |
|--------|--------|
| **pacman-contrib** | Provides `checkupdates` for the `custom/pacman` module (pending official updates). |
| **yay** (or another AUR helper) | Used by `custom/pkg-aur` to count AUR updates. Adjust the `exec` in config if you use `paru`, `pacaur`, etc. |

## Power & session

| Package | Purpose |
|--------|--------|
| **wlogout** | Power menu launched by the `custom/power` button. |

## Notifications & UI

| Package | Purpose |
|--------|--------|
| **libnotify** | Provides `notify-send` for the `custom/user` tooltip. |

## Terminal & on-click actions

| Package | Purpose |
|--------|--------|
| **kitty** | Terminal used for: temperature/cpu → `btop`, pacman updates → `fastfetch` + `sudo pacman -Syu`. |
| **btop** | Shown when clicking the CPU or temperature module. |
| **fastfetch** | Shown before system update when clicking the pacman module. |

If you use another terminal (e.g. alacritty, foot), change the `on-click` commands in the config accordingly.

## Network

- The **network** module is built into Waybar (no extra package for the widget).
- **On-click**: runs `~/.config/rofi/wifi/script.sh`. You need:
  - **rofi** (or adjust the script path/command)
  - A working wifi script at that path (often using `nmcli` from **networkmanager**).

## Fonts

| Font / package | Purpose |
|----------------|--------|
| **JetBrainsMono Nerd Font** | Main bar font set in `style.css`. Install a Nerd Font variant (e.g. `ttf-jetbrains-mono-nerd` on Arch). |
| **Font Awesome** (optional) | Referenced in the battery module for a plug icon; Nerd Fonts often cover this. |

## Optional / configured but unused in current layout

- **blueman** (or **blueman-manager**): used only if you enable the `bluetooth` module and its `on-click` to open the Bluetooth manager.
- **curl**, **xclip**, **nmap**: only needed if you enable `custom/public-ip` and use its click actions.
- **alacritty**: referenced in `custom/public-ip` for an nmap command; not used by the active modules.

## Summary (minimal set for this config)

- **waybar**
- **wireplumber**
- **playerctl**
- **pacman-contrib**
- **yay** (or your AUR helper)
- **wlogout**
- **libnotify**
- **kitty**
- **btop**
- **fastfetch**
- **rofi** (if you use the network on-click script)
- **JetBrainsMono Nerd Font** (or another Nerd Font and update `style.css`)

On Arch-based systems you can install the main dependencies with:

```bash
sudo pacman -S waybar wireplumber playerctl pacman-contrib wlogout libnotify kitty btop fastfetch rofi
yay -S ttf-jetbrains-mono-nerd   # or your AUR helper
```

Install **yay** first if you don’t have an AUR helper. Adjust for Hyprland vs other compositors and for your chosen terminal/fonts.
