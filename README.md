# Dotfiles

Hyprland-based desktop configuration for Arch Linux: compositor, status bar, file manager, and system info.

For a complete NVIDIA, Windows dual-boot, and Secure Boot installation walkthrough, see [CachyOS desktop setup](CACHYOS_SETUP.md).

## Structure

| Folder      | Description |
|------------|-------------|
| **hypr/**  | Hyprland compositor config (`hyprland.conf`, `keybinds.conf`, `hyprpaper.conf`, `hyprlock.conf`) |
| **waybar/**| Waybar status bar (config, layouts, CSS, scripts). See [waybar/dependency.md](waybar/dependency.md) for module-level details. |
| **wlogout/** | Session power menu layout and style (lock uses `hyprlock`) |
| **yazi/**  | Yazi terminal file manager config and keymap |
| **fastfetch/** | Fastfetch system info config |
| **usr/share/sddm** | SDDM login manager themes (includes Silent) and configs |

## Dependencies

Target: **Arch Linux** (pacman + AUR). Adjust for your terminal, AUR helper, and compositor.

### Pacman (official repos)

```bash
sudo pacman -S \
  base-devel \
  git \
  hyprland \
  hyprpaper \
  hyprlock \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  waybar \
  pipewire \
  pipewire-pulse \
  wireplumber \
  playerctl \
  pacman-contrib \
  wlogout \
  libnotify \
  kitty \
  btop \
  fastfetch \
  yazi \
  rofi \
  dolphin \
  networkmanager \
  network-manager-applet \
  swaync \
  grim \
  slurp \
  wl-clipboard \
  brightnessctl \
  power-profiles-daemon \
  qt6ct \
  gnome-settings-daemon \
  fish \
  vlc \
  imv \
  neovim \
  sddm \
  qt6-svg \
  qt6-virtualkeyboard \
  qt6-multimedia \
  qt6-multimedia-ffmpeg \
  qt6-imageformats
```

### AUR

Install an AUR helper first (e.g. [yay](https://github.com/Jguer/yay)), then:

```bash
# App launcher & clipboard (used in hyprland.conf autostart)
yay -S walker-bin elephant-all

# Browser (set as $browser in hyprland.conf)
yay -S zen-browser-bin

# Nerd font for Waybar (or use ttf-jetbrains-mono-nerd)
yay -S ttf-jetbrains-mono-nerd
```

### Optional / replaceable

- **yay** – Waybar’s `custom/pkg-aur` uses it; use another AUR helper and change the `exec` in `waybar/config.jsonc` if needed.
- **obsidian**, **cursor** / **cursor-bin**, **vesktop** – Keybound in `hypr/keybinds.conf`; install if you use them.
- **blueman** – Only if you enable Waybar’s `bluetooth` module and its `on-click` (e.g. `blueman-manager`).
- **qt6ct** – Qt theming; optional if you don’t care about Qt app appearance.
- **sddm-silent-theme** – AUR package alternative to copying `usr/share/sddm/themes/silent` from this repo.
- **sbctl** – Required only for the Secure Boot workflow in [CACHYOS_SETUP.md](CACHYOS_SETUP.md).

## Quick install (packages only)

```bash
# Core + Waybar + Hyprland helpers + SDDM (Silent theme Qt deps)
sudo pacman -S base-devel git hyprland hyprpaper hyprlock \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  waybar pipewire pipewire-pulse wireplumber playerctl pacman-contrib wlogout libnotify \
  kitty btop fastfetch yazi rofi dolphin networkmanager network-manager-applet \
  swaync grim slurp wl-clipboard brightnessctl power-profiles-daemon qt6ct \
  gnome-settings-daemon fish vlc imv neovim sddm qt6-svg qt6-virtualkeyboard \
  qt6-multimedia qt6-multimedia-ffmpeg qt6-imageformats --needed

# AUR (with yay)
yay -S walker-bin elephant-all zen-browser-bin ttf-jetbrains-mono-nerd
```

## Setup

1. Clone and symlink configs into `~/.config/`:

   ```bash
   git clone <this-repo> ~/Projects/Dotfiles
   cd ~/Projects/Dotfiles
   ln -s ~/Projects/Dotfiles/hypr   ~/.config/hypr
   ln -s ~/Projects/Dotfiles/waybar ~/.config/waybar
   ln -s ~/Projects/Dotfiles/wlogout ~/.config/wlogout
   ln -s ~/Projects/Dotfiles/yazi   ~/.config/yazi
   ln -s ~/Projects/Dotfiles/fastfetch ~/.config/fastfetch
   ```

2. **Hyprland**: Uses `kitty`, `dolphin`, `walker`, `zen-browser`; change `hyprland.conf` if you use different apps.
3. **Waybar**: Uses `fish` and `kitty` in some on-click commands; see [waybar/dependency.md](waybar/dependency.md) for modules and alternatives.
4. **Yazi**: Opens `nvim`, `vlc`, and `imv` for edit/play/images; uses `kitty` and `fish` in the opener. Adjust `yazi.toml` if your stack differs.
5. **wlogout**: Lock action runs `hyprlock`; other actions use `systemctl` / `loginctl`.
6. **SDDM (Silent)**: Copy or symlink `usr/share/sddm/themes/silent` into `/usr/share/sddm/themes/`, set the theme in `/etc/sddm.conf`, and enable `InputMethod=qtvirtualkeyboard`. Test with the theme’s `test.sh` before reboot. See the theme’s README for details.
7. **Fastfetch**: Optional `~/.config/fastfetch/logo.png`; config works without it.

## Fonts

Waybar’s style expects a Nerd Font (e.g. **JetBrains Mono Nerd**). Install one and ensure it’s set in `waybar/style.css` (or the CSS file your config uses).

## License

Per-component (e.g. Waybar config is MIT). See file headers where present.
