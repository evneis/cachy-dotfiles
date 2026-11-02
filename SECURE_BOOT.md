# Secure Boot on CachyOS with Limine

A complete, self-contained procedure for enabling UEFI Secure Boot on this
machine's profile:

- NVIDIA GPU;
- UEFI firmware, no CSM;
- Windows and CachyOS on separate physical drives;
- Btrfs root with Limine;
- no Linux hibernation;
- Secure Boot enabled only after everything else works.

This document supersedes [section 6 of CACHYOS_SETUP.md](CACHYOS_SETUP.md#6-enable-secure-boot)
where the two differ. It was checked on **2026-11-01** against the CachyOS wiki
(last edited 2026-08-25), Limine 12.9.4, and the current `limine-entry-tool`
configuration. Source links are at the end.

> **Read this whole document before touching firmware keys.** A mistake here
> costs a live USB and an hour, not just a reboot.

---

## 0. The short version

1. Get CachyOS, the NVIDIA driver, Limine, and Windows all booting with Secure
   Boot **off**.
2. Enter Setup Mode in firmware. On ASUS and Gigabyte, delete all Secure Boot
   variables from Key Management.
3. `sbctl create-keys`, then `sbctl enroll-keys --microsoft` — **not**
   `--firmware-builtin` on ASUS/Gigabyte.
4. Reboot before trusting `sbctl status`.
5. Enable Limine config enrollment, snapshot re-enrollment, and the fallback
   loader.
6. Enroll and sign: `limine-enroll-config`, then `limine-update`.
7. Only then turn Secure Boot on in firmware.
8. Never `sbctl sign` a kernel. Never set `ENABLE_VERIFICATION=no`.

---

## 1. Know which Limine you have

This matters more than any other detail, because the security policy changed
three times and most forum advice is version-specific.

| Limine version | Config checksum enrolled? | Behaviour |
| --- | --- | --- |
| ≤ 11.1.x | — | No hash enforcement. |
| 11.2.0 | Required | Strict enforcement. Broke many installs on upgrade. |
| 11.2.1 | Optional | Enforcement reverted. |
| 12.x | Opt-in | Enforcement returns **only if** a checksum is enrolled. |

CachyOS currently ships **Limine 12.9.4** (built 2026-10-24). Check yours:

```bash
pacman -Q limine
```

The practical consequence for Limine 12.x: enrolling a config checksum is
explicit opt-in to strict mode. Once you opt in, every file Limine loads
natively (kernel, initramfs) must carry a BLAKE2B hash, the config editor is
disabled, and any hash mismatch is a panic. If you enroll, you must also
automate re-enrollment (section 6) or the next snapshot or kernel rebuild will
lock you out.

If a thread you are reading says "just add the wallpaper hash" and nothing
else, it predates 12.x or postdates the 11.2.1 revert. Check the date.

---

## 2. Pre-flight

Do not skip this. Every recovery story in the forum threads starts with one of
these being skipped.

### 2.1 Windows side

```powershell
powercfg /H off
```

```bat
manage-bde -status
```

`Encryption Method` must read `None`. CachyOS's dual-boot prerequisites require
BitLocker to be disabled during installation. If you re-enable BitLocker after
installation, keep the recovery key off-machine — firmware key changes can
prompt for it.

Fully shut down Windows. Do not use Restart.

### 2.2 Have a recovery path

- A CachyOS live USB that you have actually booted once.
- Your BitLocker recovery key, if BitLocker is or will be enabled.
- Knowledge of how to disable Secure Boot in your firmware (usually the same
  menu you are about to edit).

If Limine panics under Secure Boot, snapshots do **not** help — the bootloader
never reaches them. The live USB and the firmware toggle are the only exits.

### 2.3 Confirm the baseline

With Secure Boot off, verify all four of these, in this order:

```bash
pacman -Q limine sbctl
sudo limine-scan          # Windows appears in the menu
nvidia-smi                # driver works
systemctl reboot --firmware-setup   # firmware entry works
```

Then boot Windows once from Limine and back into CachyOS. Do not proceed until
this is boring and repeatable.

---

## 3. Enter Setup Mode

Install the key manager and look at the current state:

```bash
sudo pacman -S --needed sbctl
sudo sbctl status
```

> **Cosmetic quirk:** before you create keys, `sbctl status` reports
> `Installed: ✘ sbctl is not installed`. That is sbctl describing the absence of
> *its own* keys, not a missing package. Ignore it.

Reboot straight to firmware:

```bash
systemctl reboot --firmware-setup
```

Set the firmware into Setup Mode (also called Custom Mode on some boards) and
leave Secure Boot itself **disabled**. Firmware menus differ enough that the
generic instruction is the main reason people get stuck, so use the table:

| Vendor | Where to go | The trap |
| --- | --- | --- |
| **ASUS** | Boot → Secure Boot → Secure Boot Mode = **Custom** → Key Management → **Delete all Secure Boot Variables** | OS Type must be **Windows UEFI Mode**. "Other OS" leaves Secure Boot permanently off. |
| **MSI** | Secure Boot Mode = **Custom**, and set the compatibility option to **maximum security** | With the default compatibility mode the board may refuse to boot a non-Windows bootloader at all. |
| **Gigabyte** | Secure Boot → **Reset to setup mode** | A "reset without saving" dialog appears immediately after. **Reject it** — accepting cancels Setup Mode. Boot the OS directly via Save & Exit → Boot Override. |
| **Dell** | Secure Boot → Expert Key Management | Audit Mode = **Other OS**, Custom Mode = **Custom Keys**, then delete all keys. Deployment Mode stays Windows. |
| **Lenovo** | Security → Secure Boot → **Reset to Setup Mode** | Firmware updates via Lenovo Vantage can wipe both the keys and the Limine NVRAM entry. |

If your board has no Setup Mode and no key deletion, stop here and read the
vendor-specific notes in the CachyOS wiki before deleting anything.

### 3.1 The "clear all keys" caution, correctly stated

Clearing variables is the *normal* path, not a last resort. The real risk is
not Windows — Windows boots fine once you re-enroll Microsoft's keys in the next
step. The risk is ending up with no working bootloader and no live USB.

So: clear the keys, but only after 2.2 is done.

---

## 4. Create and enroll keys

Back in CachyOS, confirm Setup Mode is on:

```bash
sudo sbctl status
```

`Setup Mode: ✓ Enabled` is what you want. Then:

```bash
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
sudo sbctl status
```

### 4.1 Why `--microsoft` and not `--firmware-builtin`

`--microsoft` adds the Microsoft certificates. That is what keeps **Windows
Boot Manager** bootable, and it also covers most option ROMs.

`--firmware-builtin` additionally copies the OEM's built-in certificates. On
**ASUS and Gigabyte** this produces duplicate `builtin-db` entries, and when you
later enable Secure Boot the board throws a **Secure Boot Violation** before
Limine ever loads. The CachyOS wiki now says this explicitly:

> Use only `--microsoft` on ASUS / Gigabyte boards.

On other boards, `--firmware-builtin` is useful for OEM firmware and GPU option
ROMs. If you are unsure of your board, use `--microsoft` alone — it is the
safer default and does not affect Windows.

If you already ran the combined form and see duplicates:

```text
Vendor Keys:    microsoft builtin-db builtin-db builtin-KEK
```

go back to firmware, delete all keys, re-enter Setup Mode, and re-run
`sbctl enroll-keys --microsoft`.

### 4.2 Stop conditions

- `enroll-keys` prints an error → stop. Do not enable Secure Boot.
- `Setup Mode` still shows **Enabled** → do not panic yet; go to section 5.
- `Vendor Keys` shows duplicates → fix as above.

---

## 5. Verify enrollment (reboot first)

The efivars view is frequently stale. Reboot, then check:

```bash
sudo sbctl status
```

Target state:

```text
Setup Mode:     ✓ Disabled
Secure Boot:    ✗ Disabled      # still off, that is correct
Vendor Keys:    microsoft       # no duplicate builtin-* entries
```

If `Setup Mode` is still **Enabled** after a reboot, re-enter firmware, delete
all keys, and repeat section 4. Do not proceed on a stale reading.

### 5.1 `File is immutable`

If enrollment fails with:

```text
‼ File is immutable: /sys/firmware/efi/efivars/PK-...
```

clear the immutable flag and retry:

```bash
sudo chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}-*
sudo sbctl enroll-keys --microsoft
```

This is a known sbctl/efivarfs interaction and is safe.

### 5.2 If `enroll-keys` reports "not in Setup Mode" but the firmware says it is

Some firmware only exposes Setup Mode after a full power cycle rather than a
warm reboot. Shut down, power on, re-check `sbctl status` before touching the
keys again.

---

## 6. Configure Limine enrollment

This is the part that most guides under-document, and the part that breaks
installs months later.

### 6.1 Check what your tooling actually supports

Option names in `limine-entry-tool` have changed across releases. Read the
installed documentation rather than trusting a blog post:

```bash
grep -n -B4 -E 'ENABLE_ENROLL_LIMINE_CONFIG|ENABLE_VERIFICATION|ENABLE_LIMINE_FALLBACK|COMMANDS_' \
  /etc/limine-entry-tool.conf /etc/limine-entry-tool.d/*.conf 2>/dev/null
```

### 6.2 Enable config enrollment

Edit `/etc/default/limine` and add:

```ini
ENABLE_ENROLL_LIMINE_CONFIG=yes
```

The tool's own warning is worth reading in full: enabling this **prevents
booting** if `limine.conf` changes and is not re-enrolled.

### 6.3 Keep verification hashes on

`ENABLE_VERIFICATION` defaults to `yes`, which makes `limine-entry-tool` append
BLAKE2B hashes to the kernel and initramfs paths it generates. Leave it on.

- Missing **kernel/initramfs** hash under enforcement → panic.
- Missing **wallpaper/font** hash → silently skipped, so you get a white or
  blank Limine menu rather than a failure.

Forum advice to set `ENABLE_VERIFICATION=no` exists to work around
`sbctl-batch-sign` conflicts. Do not apply it here — this setup never signs
kernels, so the conflict does not arise, and turning it off makes every native
kernel entry unhashable.

### 6.4 Automate re-enrollment for snapshots

CachyOS ships Limine with automatic Btrfs snapshots. `limine-snapper-sync`
rewrites `limine.conf` when it creates or syncs a snapshot, which changes the
config hash. Without re-enrollment, the next boot is:

```text
PANIC: !!! SECURE BOOT IS ACTIVE BUT NO CONFIG CHECKSUM IS ENROLLED !!!
```

Add to **both** `/etc/default/limine` and `/etc/limine-snapper-sync.conf`:

```ini
COMMANDS_BEFORE_SAVE="limine-reset-enroll"
COMMANDS_AFTER_SAVE="limine-enroll-config"
```

Verify the keys exist in your installed version before relying on them (6.1).

### 6.5 Keep a fallback

Add a fallback loader so a config mismatch is recoverable without a live USB:

```ini
ENABLE_LIMINE_FALLBACK=yes
```

Deploy it once, then confirm the standard UEFI path exists:

```bash
sudo limine-update          # or: sudo limine-install --fallback
ls -l /boot/EFI/BOOT/BOOTX64.EFI
```

This is the recommendation in the tool's own documentation for exactly this
situation. Note that the fallback is also a bootloader binary — if you later
enroll or sign it, you lose the recovery property, so leave it as-is unless
section 10.1 applies to your board.

### 6.6 Hash the wallpaper (optional, cosmetic)

```bash
sudo b2sum /boot/limine-splash.png
sudoedit /boot/limine.conf
```

Append the hash after `#`:

```text
wallpaper: boot():/limine-splash.png#FULL_BLAKE2_HASH
```

Use the real path from *your* `limine.conf`, and the hash from *your* file. This
only affects whether the splash image renders. It is not a security control.

---

## 7. Enroll the config and sign Limine

```bash
sudo limine-enroll-config
sudo limine-update
sudo sbctl status
```

Order matters: enroll the current config, then let the update tool redeploy,
re-enroll, and re-sign the EFI binary.

Check signatures:

```bash
sudo sbctl verify
```

Expected results:

- `limine_x64.efi` — **signed**.
- Kernel files under `/boot/<machine-id>/...` — may show **unsigned**.
  That is correct and expected. Limine verifies them by BLAKE2B hash, not by
  signature. Signing them would change the hash and break the boot.

---

## 8. Enable Secure Boot

```bash
systemctl reboot --firmware-setup
```

Enable Secure Boot, save, and boot CachyOS. Then:

```bash
sudo sbctl status          # Secure Boot: ✓ Enabled
bootctl                    # Secure Boot: enabled (user)
dmesg | grep -i "secure boot"
nvidia-smi
```

`bootctl` prints "systemd-boot not installed in ESP" on a Limine system. That
line is noise; the `Secure Boot:` line is the one that matters.

Test, in this order:

1. Default CachyOS entry.
2. Any LTS kernel entry.
3. A snapshot entry (proves 6.4 works).
4. Windows.

If any of these fails, go to section 10 before changing anything else.

---

## 9. Maintenance

| Event | What happens | What to do |
| --- | --- | --- |
| Kernel update | `limine-mkinitcpio-hook` regenerates entries and hashes, then re-enrolls | Nothing, if 6.2–6.4 are set. Verify with `sudo sbctl status` after the first one. |
| Snapshot created/restored | `limine-snapper-sync` rewrites `limine.conf` | Nothing, if 6.4 is set. Otherwise: `limine-enroll-config && limine-update`. |
| You edit `limine.conf` by hand | Hash changes, enrollment stale | `sudo limine-enroll-config && sudo limine-update` |
| `limine` package update | EFI binary replaced | `limine-update` should handle it; confirm with `sbctl verify`. |
| BIOS/firmware update | ASUS/Lenovo may wipe keys and NVRAM entries | Re-run sections 3–5, then 8. Keep the live USB nearby. |
| Btrfs rollback | Older config may not match enrolled hash | Boot the fallback loader, then re-enroll. |

---

## 10. Recovery

Work down the list; do not clear keys repeatedly.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `PANIC: SECURE BOOT IS ACTIVE BUT NO CONFIG CHECKSUM IS ENROLLED` | Config changed after enrollment (snapshot, manual edit, package update) | Disable Secure Boot in firmware → boot → `limine-enroll-config && limine-update` → re-enable |
| Same panic, but enrollment commands succeed | Firmware is booting `/boot/EFI/BOOT/BOOTX64.EFI`, not `limine_x64.efi` | See 10.1 |
| `Secure Boot Violation` before Limine loads | Duplicate `builtin-db` from `--firmware-builtin` on ASUS/Gigabyte | Delete all keys, re-enter Setup Mode, re-enroll with `--microsoft` only |
| Hash mismatch panic on a kernel entry | `ENABLE_VERIFICATION=no`, or a stale hash after a manual edit | Set it back to `yes`, `limine-update` |
| White/blank Limine menu | Wallpaper hash missing | Re-add the wallpaper hash, or ignore — cosmetic only |
| Secure Boot will not stay enabled | Firmware needs the correct OS Type / compatibility mode | ASUS: Windows UEFI Mode. MSI: maximum security. |
| `enroll-keys` says "not in Setup Mode" | Stale efivars, or Setup Mode was cancelled | Full power cycle, re-check status, re-enter Setup Mode |
| `File is immutable` | efivarfs flags | `chattr -i` per 5.1 |
| Windows will not boot | Microsoft keys not enrolled | Re-enroll with `--microsoft`, confirm `Vendor Keys: microsoft` |

### 10.1 When firmware ignores the Limine NVRAM entry

Some Acer, MSI, and ASUS boards deprioritise custom NVRAM entries and fall back
to the standard UEFI path `/boot/EFI/BOOT/BOOTX64.EFI`. `limine-enroll-config`
only enrolls into `limine_x64.efi`, so the fallback binary has no checksum and
panics.

Diagnose:

```bash
sudo sbctl verify
bootctl
```

If `BOOTX64.EFI` is unsigned or unenrolled while `limine_x64.efi` is fine, that
is your cause.

The community fix is to sync and sign the fallback:

```bash
sudo cp /boot/EFI/limine/limine_x64.efi /boot/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign /boot/EFI/BOOT/BOOTX64.EFI
```

Treat this as a last resort. The `limine-entry-tool` author warns that
enrolling the fallback removes your last non-USB recovery path, and recommends
keeping **systemd-boot** as the fallback instead. Do not copy the "delete
`limine_x64.bak`" advice found in some threads — that archive is what lets
Limine reset a signed binary before re-enrolling, and deleting it leads to
recursive signing and a corrupted bootloader.

---

## 11. Anti-patterns

Things that appear in threads and that you should not do here:

- `sbctl enroll-keys --microsoft --firmware-builtin` on ASUS or Gigabyte.
- `sbctl sign` on kernels or initramfs under Limine.
- `ENABLE_VERIFICATION=no`.
- `rm /boot/EFI/limine/limine_x64.bak`.
- Enrolling or signing `BOOTX64.EFI` without understanding that it is your
  recovery path.
- Repeatedly clearing firmware keys instead of diagnosing the first failure.
- Trusting `sbctl status` immediately after `enroll-keys` without a reboot.
- Following a guide without checking which Limine version it was written for.

---

## 12. Sources

### Primary documentation

- [CachyOS Secure Boot Setup](https://wiki.cachyos.org/configuration/secure_boot_setup/) —
  the authoritative procedure; contains the ASUS/Gigabyte `--firmware-builtin`
  warning and the Limine hash steps.
- [CachyOS installation and dual boot](https://wiki.cachyos.org/installation/installation_on_root/) —
  BitLocker, Fast Startup, and Secure Boot prerequisites.
- [CachyOS Boot Manager Configuration](https://wiki.cachyos.org/configuration/boot_manager_configuration/) —
  `/etc/default/limine`, `limine-mkinitcpio`, automatic kernel entries.
- [CachyOS March 2026 release](https://www.cachyos.org/blog/2603-march-release) —
  Limine becomes the default bootloader with automatic snapshots.
- [Limine 12.x ChangeLog](https://github.com/Limine-Bootloader/Limine/blob/v12.x/ChangeLog) —
  11.2.0 enforcement, 11.2.1 revert, 12.x re-introduction.
- [Limine 12.x USAGE.md](https://github.com/Limine-Bootloader/Limine/blob/v12.x/USAGE.md) —
  enforcement is opt-in via enrolled checksum; wallpapers silently skipped.
- [limine-entry-tool](https://gitlab.com/Zesko/limine-entry-tool) —
  `ENABLE_VERIFICATION`, `ENABLE_ENROLL_LIMINE_CONFIG`,
  `ENABLE_LIMINE_FALLBACK`, `COMMANDS_*`.
- [CachyOS package: limine 12.9.4](https://dashboard.cachyos.org/package/cachyos/x86_64/limine) —
  current shipped version.
- [ArchWiki: Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot) —
  background on sbctl and key enrollment.
- [sbctl](https://github.com/Foxboron/sbctl) — upstream key manager.

### Community threads corroborating the failure modes

- [Limine and Secure Boot step-by-step instructions?](https://discuss.cachyos.org/t/limine-and-secure-boot-step-by-step-instructions/32468) —
  ASUS-specific sequence, `--firmware-builtin` warning, `chattr -i`,
  stale-efivars reboot, and the "unsigned kernels are expected" note.
- [Secure boot not working with limine despite following the guide](https://discuss.cachyos.org/t/secure-boot-not-working-with-limine-despite-following-cachyos-secure-boot-guide/26442) —
  duplicate `builtin-db` output, the 11.2.0 panic, the wallpaper hash fix, and
  the two-reboot pattern.
- [After latest update, my secure boot no longer works](https://discuss.cachyos.org/t/after-latest-update-my-secure-boot-no-longer-works/27147) —
  the 11.2.0 panic and its resolution.
- [Acer Predator 16 secure boot resolution](https://discuss.cachyos.org/t/acer-predator-16-secure-boot-resolution/27191) —
  firmware booting `BOOTX64.EFI`, `limine-update` invalidating enrollment, and
  the maintainer's reply on versions, `ENABLE_VERIFICATION`, and why deleting
  `limine_x64.bak` is wrong.
- [Cannot get BIOS Secure Boot into setup mode](https://discuss.cachyos.org/t/cannot-get-bios-secure-boot-into-setup-mode/22189) —
  Gigabyte "Reset to setup mode" trap and duplicate vendor keys.
- [Help enabling Secure Boot on a 2021 ASUS G14](https://discuss.cachyos.org/t/help-enabling-secure-boot-on-a-2021-asus-g14-laptop/34595) —
  "not in Setup Mode" despite firmware settings, and `File is immutable`.
- [Re-enable Secure Boot after CachyOS with Limine (Dell Latitude 7400)](https://discuss.cachyos.org/t/re-enable-bios-secureboot-after-cachyos-w-limine-install-dell-latitude-7400/36549) —
  Dell Deployment/Audit/Custom mode mapping.
- [Boot error after BIOS update (Lenovo)](https://discuss.cachyos.org/t/boot-error-after-update-bios-with-lenovo-vantage/35954) —
  firmware updates wiping keys and NVRAM entries; `efibootmgr` re-registration.
- [Secure Boot with Limine and snapshots](https://discuss.cachyos.org/t/is-there-a-solution-for-making-secure-boot-work-with-limine-snapshots/8148) —
  the `sbctl-batch-sign` vs. hash-verification conflict and why
  `ENABLE_VERIFICATION=no` is sometimes suggested (and why it is wrong here).
- [Arch forum: unable to enable Secure Boot on ASUS](https://bbs.archlinux.org/viewtopic.php?id=288688) —
  "Other OS" means Secure Boot off; Windows UEFI Mode is required.
- [Arch forum: can't enable Secure Boot on ASUS X670E](https://bbs.archlinux.org/viewtopic.php?id=307674) —
  Custom mode plus key deletion, and firmware quirks around key enrollment.
- [sbctl issue #115: file is immutable](https://github.com/Foxboron/sbctl/issues/115) —
  the `chattr -i` remedy.
- [sbctl issue #171: permission denied while enrolling](https://github.com/Foxboron/sbctl/issues/171) —
  Setup Mode requirements and stale-state behaviour.
- [r/cachyos: fix for the Limine 11.2.0 Secure Boot panic](https://www.reddit.com/r/cachyos/comments/1sbeem2/guide_fix_limine_1120_secure_boot_panic_blank/) —
  the wallpaper-hash + enroll sequence that circulated in April 2026.
- [NixOS wiki: Limine](http://wiki.nixos.org/wiki/Limine) —
  cross-distro confirmation that `--microsoft --firmware-builtin` is the generic
  default, which is why the ASUS/Gigabyte exception is easy to miss.
