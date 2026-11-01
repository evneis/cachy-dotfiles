# CachyOS desktop setup

This guide installs CachyOS beside Windows on a separate physical drive, then
applies this repository's Hyprland configuration. It is tailored to:

- an NVIDIA GPU;
- UEFI firmware;
- Windows and CachyOS on separate drives;
- Btrfs with Limine;
- Secure Boot enabled after installation;
- no Linux hibernation; and
- the Linux username `evan`.

Read the whole guide before changing partitions or Secure Boot keys. Back up
anything that cannot be replaced.

> **Current config note:** This repository now uses a Lua-based Hyprland
> configuration (`hypr/hyprland.lua` and `hypr/keybinds.lua`). Where this guide
> refers to `hyprland.conf` or `keybinds.conf`, use the Lua files. For the
> post-install wiring checklist, see [WIRING.md](WIRING.md).

## 1. Before downloading CachyOS

### Back up Windows

1. Back up important files.
2. Save the Windows BitLocker recovery key somewhere other than this computer.
3. In **Disk Management**, record the model and size of the Windows disk and the
   empty disk intended for CachyOS. These identifiers are the main protection
   against formatting the wrong drive.
4. Open PowerShell as Administrator and disable Windows Fast Startup and
   hibernation:

   ```powershell
   powercfg /H off
   ```

5. Check BitLocker from an Administrator Command Prompt:

   ```bat
   manage-bde -status
   ```

   CachyOS's dual-boot instructions require BitLocker to be disabled during
   installation. If the CachyOS target drive or Windows system volume is
   encrypted, decrypt it in **Manage BitLocker** and wait until
   `manage-bde -status` reports `Encryption Method: None`.

6. Fully shut Windows down. Do not merely restart into the installer.

### Prepare the firmware

Enter the UEFI settings and:

- use UEFI mode, not Legacy/CSM;
- temporarily disable Secure Boot;
- leave the Windows drive connected, but double-check disk identities in the
  installer; and
- put the USB drive first for the next boot, or use the one-time boot menu.

Secure Boot is re-enabled in [section 6](#6-enable-secure-boot). It must remain
off until CachyOS has booted successfully and Limine has been enrolled.

## 2. Download and flash the ISO

1. Download the current **CachyOS Desktop Edition** ISO from the
   [official download page](https://cachyos.org/download/).
2. Download or copy the SHA-256 checksum shown by the official mirror. In
   PowerShell, verify the downloaded ISO:

   ```powershell
   Get-FileHash .\cachyos-desktop-linux-*.iso -Algorithm SHA256
   ```

   Continue only when the hash exactly matches the published checksum.

3. Flash the ISO to a USB drive with
   [Rufus](https://rufus.ie/) or another image writer. In Rufus:
   - select the CachyOS ISO;
   - select the USB drive, checking its model and size;
   - keep the GPT/UEFI defaults;
   - start the write and choose **DD Image mode** if prompted.

The USB drive is erased by this operation.

## 3. Install CachyOS

Boot the USB's UEFI entry. Connect to the internet in the live environment;
CachyOS uses an online installer.

### Start Calamares

Launch the graphical installer and make these selections:

1. **Language:** English (United States), or the language you actually use.
2. **Region and timezone:** your physical location.
3. **Keyboard:** English (US). If using another layout, also change
   `kb_layout = us` later in `hypr/hyprland.lua`.
4. **Partitioning:** Manual partitioning.
5. **Boot manager:** Limine.
6. **Filesystem:** Btrfs for `/`.
7. **Desktop:** Hyprland. If the current installer labels it
   **Hyprland Noctalia**, select that profile. Its generated configuration is
   only a working bootstrap and will be backed up before these dotfiles are
   linked.
8. **Audio and networking:** keep PipeWire/WirePlumber and NetworkManager.
9. **Optional packages:** keep the defaults. Add gaming, printing, Bluetooth,
   or development groups only if needed; none is required by these dotfiles.
10. **User:** create `evan`, use a strong password, and enable administrator
    privileges for the account. The current configs contain `/home/evan`
    paths.

### Partition only the CachyOS drive

In the manual partitioner, identify the empty CachyOS drive by its model and
size. Do not create, delete, format, or assign mount points on the Windows
drive.

On the CachyOS drive:

1. Create a new GPT partition table if the drive is empty. This erases that
   drive only.
2. Create a 4096 MiB partition:
   - filesystem: FAT32;
   - mount point: `/boot`;
   - flag: `boot`.
3. Create a second partition using the remaining space:
   - filesystem: Btrfs;
   - mount point: `/`;
   - no special flag.
4. Do not create a swap partition solely for hibernation. CachyOS may create or
   offer a small swap file for memory pressure; that is fine, but this setup
   does not configure resume-from-hibernation.

The installer's summary should show formatting only on the dedicated CachyOS
drive. Stop and go back if the Windows disk or its EFI System Partition appears
in the format list.

Install, remove the USB when prompted, and reboot. Leave Secure Boot disabled.
At the Limine menu, boot CachyOS. Then reboot once into Windows and once back
into CachyOS before continuing. If Windows is absent from Limine, fix that in
[section 7](#windows-is-missing-from-limine).

## 4. Update and verify the base system

Open a terminal in the installer-provided Hyprland session:

```bash
sudo pacman -Syu
sudo reboot
```

After reboot, verify the hardware profile:

```bash
chwd --list-installed
lspci -k | grep -A 3 -E '(VGA|3D)'
nvidia-smi
```

`nvidia-smi` should show the GPU and driver without an error. CachyOS normally
selects the NVIDIA profile during installation. If it did not, inspect the
available profiles and let CachyOS choose:

```bash
chwd --list-all
sudo chwd -a
sudo reboot
```

Do not copy a package name from another machine or force a legacy NVIDIA branch
without checking the GPU generation. CachyOS's `chwd` profile is the source of
truth for the installed card.

## 5. Install packages and dotfiles

### Install repository dependencies

The detailed package list is maintained in `README.md`. Install the official
repository packages:

```bash
sudo pacman -S --needed \
  base-devel git \
  hyprland hyprpaper hyprlock \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  waybar pipewire pipewire-pulse wireplumber playerctl pacman-contrib \
  wlogout libnotify kitty btop fastfetch yazi rofi dolphin \
  networkmanager network-manager-applet swaync grim slurp wl-clipboard \
  brightnessctl power-profiles-daemon qt6ct gnome-settings-daemon fish \
  vlc imv neovim sddm qt6-svg qt6-virtualkeyboard qt6-multimedia \
  qt6-multimedia-ffmpeg qt6-imageformats
```

Install `yay` because the active Waybar config invokes it:

```bash
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
cd /tmp/yay-bin
makepkg -si
cd
```

Never run `makepkg` as root. Review the PKGBUILD before approving the build.
Then install the required AUR packages:

```bash
yay -S --needed walker-bin elephant-all zen-browser-bin \
  ttf-jetbrains-mono-nerd
```

The Obsidian, Cursor, and Vesktop keybindings remain inactive until those
optional applications are installed.

### Clone the repository

```bash
mkdir -p ~/Projects
git clone https://github.com/evneis/cachy-dotfiles.git ~/Projects/Dotfiles
cd ~/Projects/Dotfiles
```

If the directory already exists, do not clone over it. Instead:

```bash
git -C ~/Projects/Dotfiles status
git -C ~/Projects/Dotfiles pull --ff-only
```

Do not pull if `git status` reports local work you have not reviewed.

### Back up generated configs and create links

Run this block with Bash. It moves only the five config directories managed by
this repository and leaves a timestamped backup:

```bash
bash <<'EOF'
set -eu
repo="$HOME/Projects/Dotfiles"
backup="$HOME/.config/cachyos-backup-$(date +%Y%m%d-%H%M%S)"
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

### Personalize before logging out

Edit files in `~/Projects/Dotfiles`; the symlinks make those edits live.

1. **Monitors:** run `hyprctl monitors all`. Replace the laptop-specific
   `eDP-1` and `HDMI-A-1` `hl.monitor` blocks in `hypr/hyprland.lua` with the
   desktop's connector names, resolution, refresh rate, position, and scale. A
   safe temporary fallback is:

   ```lua
   hl.monitor({
       output   = "",
       mode     = "preferred",
       position = "auto",
       scale    = "auto",
   })
   ```

2. **Mouse:** remove or change the
   `logitech-g502-hero-gaming-mouse` device block if that is not the installed
   mouse.
3. **Wallpaper:** copy the included wallpapers with
   `cp ~/Projects/Dotfiles/images/wallpapers/*.jpg ~/Pictures/wallpapers/`, or
   place your own image there and change the paths in `hypr/hyprpaper.conf`
   and `hypr/hyprlock.conf`.
4. **User paths:** the active files currently use `/home/evan`, which is
   correct only for the `evan` account:
   - `hypr/keybinds.lua`;
   - `hypr/hyprpaper.conf`;
   - `hypr/hyprlock.conf`; and
   - `waybar/config.jsonc`.
5. **Waybar temperature:** `waybar/config.jsonc` assumes thermal zone 2 and
   `/sys/class/hwmon/hwmon2/temp1_input`. Update these for the desktop or remove
   the `temperature` module if it shows no value.
6. **Hibernate:** remove the object with `"label" : "hibernate"` from
   `wlogout/layout`. Do not select that action; resume is intentionally not
   configured.

Check the Hyprland config before ending the bootstrap session:

```bash
hyprctl configerrors
```

Resolve every reported parse error. Reload after edits with:

```bash
hyprctl reload
```

### Enable supporting services

```bash
sudo systemctl enable NetworkManager sddm power-profiles-daemon
systemctl --user enable --now pipewire.socket pipewire-pulse.socket
```

WirePlumber normally starts as a user service when PipeWire needs it. Confirm:

```bash
systemctl --user --no-pager status pipewire wireplumber
wpctl status
```

## 6. Enable Secure Boot

First confirm that CachyOS, the NVIDIA driver, Limine, and Windows all boot
while Secure Boot is off. Keep the BitLocker recovery key available.

These steps follow the
[CachyOS Secure Boot guide](https://wiki.cachyos.org/configuration/secure_boot_setup/).
Firmware menus vary, so use the motherboard manual when names differ.

### Enter firmware Setup Mode

Install the key-management tool:

```bash
sudo pacman -S --needed sbctl
sudo sbctl status
```

Reboot to firmware:

```bash
systemctl reboot --firmware-setup
```

Set Secure Boot to **Setup Mode** or **Custom Mode**. Some firmware requires
clearing existing Secure Boot variables to enter Setup Mode. Do not do that
unless the Windows recovery key is backed up and the firmware offers a way to
restore factory keys. Leave Secure Boot itself disabled, save, and boot
CachyOS.

Verify that `sbctl status` reports Setup Mode enabled, then create and enroll
keys. The Microsoft and firmware keys are retained so Windows can boot:

```bash
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl status
```

Stop if enrollment reports an error. Do not enable Secure Boot until enrollment
succeeds.

### Enroll Limine

Edit `/etc/default/limine` and set:

```ini
ENABLE_ENROLL_LIMINE_CONFIG=yes
```

Inspect `/boot/limine.conf`. If it contains a `wallpaper:` entry, calculate the
BLAKE2 hash of the referenced file and append it after `#` as required by the
CachyOS guide. For the common default:

```bash
sudo b2sum /boot/limine-splash.png
sudoedit /boot/limine.conf
```

The result has this form:

```text
wallpaper: boot():/limine-splash.png#FULL_BLAKE2_HASH
```

Use the actual path and hash from this machine. Then enroll the Limine config
and update its EFI binary:

```bash
sudo limine-enroll-config
sudo limine-update
sudo sbctl status
```

Reboot into firmware, enable Secure Boot, and boot CachyOS:

```bash
sudo sbctl status
bootctl
nvidia-smi
```

`sbctl status` should report Secure Boot enabled. Finally, boot Windows once
from Limine. Windows may ask for its BitLocker recovery key after firmware key
changes even when encryption was previously disabled.

## 7. Install the Silent SDDM theme

Install the theme dependencies if the package step did not already do so:

```bash
sudo pacman -S --needed sddm qt6-svg qt6-virtualkeyboard \
  qt6-multimedia qt6-multimedia-ffmpeg qt6-imageformats
```

Copy only the Silent theme, not the repository's entire `usr/share/sddm` tree:

```bash
sudo install -d /usr/share/sddm/themes/silent
sudo cp -a ~/Projects/Dotfiles/usr/share/sddm/themes/silent/. \
  /usr/share/sddm/themes/silent/
```

Create or edit `/etc/sddm.conf`:

```bash
sudoedit /etc/sddm.conf
```

Ensure it contains:

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

The vendored theme does not contain the upstream optional `fonts/` directory,
although its default preset requests `RedHatDisplay`. Missing that font may
change typography but should not prevent login. Change `font-family` in
`configs/default.conf` to an installed font if needed.

Enable SDDM and reboot:

```bash
sudo systemctl enable sddm
sudo reboot
```

At SDDM, select the **Hyprland** Wayland session.

## 8. Final verification

After logging into the dotfile-managed session, check:

```bash
hyprctl configerrors
hyprctl monitors all
systemctl --no-pager --failed
systemctl --user --no-pager --failed
wpctl status
nvidia-smi
sudo sbctl status
```

Then verify these interactions:

- Waybar appears and its power-profile button changes profiles.
- `Super+Return` opens Kitty.
- `Super+Space` opens Walker.
- `Super+L` opens Hyprlock.
- `Super+Shift+S` captures a region to the clipboard.
- `Super+Escape` opens wlogout without a Hibernate option.
- Yazi previews files and opens images with imv, video with VLC, and text with
  Neovim.
- NetworkManager's applet appears.
- audio output and microphone controls work.
- Windows and CachyOS both boot from Limine with Secure Boot enabled.

## Troubleshooting

### Windows is missing from Limine

Boot CachyOS and run:

```bash
sudo limine-scan
sudo limine-update
```

Reboot and check again. Also confirm that the Windows disk is visible in
firmware and that Windows Boot Manager still has a UEFI entry.

### Hyprland starts with a blank or unusable display

Switch to another TTY with `Ctrl+Alt+F3`, log in, and replace the `hl.monitor`
blocks in `~/Projects/Dotfiles/hypr/hyprland.lua` with:

```lua
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
```

Return to SDDM or reboot, run `hyprctl monitors all`, and then configure the
exact outputs.

### NVIDIA fails after an update

Do not install a random driver branch. From a TTY:

```bash
chwd --list-installed
sudo chwd -a
sudo mkinitcpio -P
sudo reboot
```

If this does not resolve the issue, use an older Btrfs snapshot from Limine and
consult the [CachyOS chwd documentation](https://wiki.cachyos.org/features/chwd/chwd/).

### SDDM is blank

Switch to a TTY, restore a basic theme, and restart SDDM:

```bash
sudoedit /etc/sddm.conf
sudo systemctl restart sddm
```

Set `Current=` to the previously working theme or remove the line temporarily.
For an NVIDIA-specific Silent theme crash, consult the theme's
`docs/Snippets.md` before adding environment workarounds.

### Secure Boot no longer boots CachyOS

Disable Secure Boot in firmware to recover, boot CachyOS, and inspect:

```bash
sudo sbctl status
sudo limine-enroll-config
sudo limine-update
```

Re-enable Secure Boot only after those commands succeed. Do not clear firmware
keys repeatedly; restore factory keys if Windows also stops booting.

## References

- [CachyOS preparation](https://wiki.cachyos.org/installation/installation_prepare/)
- [CachyOS desktop installation and dual boot](https://wiki.cachyos.org/installation/installation_on_root/)
- [CachyOS boot managers](https://wiki.cachyos.org/installation/boot_managers/)
- [CachyOS Secure Boot](https://wiki.cachyos.org/configuration/secure_boot_setup/)
- [CachyOS hardware detection (`chwd`)](https://wiki.cachyos.org/features/chwd/chwd/)
