#!/usr/bin/env bash
# Regenerate the package snapshot in this directory.
#
# Hardware-specific packages are intentionally excluded so the snapshot can be
# reused on a machine with a different kernel/GPU:
#   - kernels and kernel headers
#   - the NVIDIA driver stack
# The third-party `cider` package is also kept out of the main lists; it lives
# in cider.txt because it comes from the cidercollective repo, not the AUR.
set -euo pipefail

dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exclude=(
  # Kernels and headers
  linux-cachyos linux-cachyos-headers
  linux-cachyos-lts linux-cachyos-lts-headers
  # NVIDIA driver stack
  nvidia-580xx-dkms nvidia-580xx-settings nvidia-580xx-utils
  lib32-nvidia-580xx-utils
  opencl-nvidia-580xx lib32-opencl-nvidia-580xx
  libva-nvidia-driver nvidia-prime
  # Third-party repo package (see cider.txt)
  cider
)

tmpconf="$(mktemp)"
tmpexclude="$(mktemp)"
tmpnative="$(mktemp)"
tmpforeign="$(mktemp)"
trap 'rm -f "$tmpconf" "$tmpexclude" "$tmpnative" "$tmpforeign"' EXIT
printf '%s\n' "${exclude[@]}" > "$tmpexclude"

# A broken or unsigned third-party repo makes `pacman -Qqen`/`-Qqem` abort.
# Query against a temporary config with the cidercollective block removed.
sed '/^\[cidercollective\]/,/^$/d' /etc/pacman.conf > "$tmpconf"

pacman --config "$tmpconf" -Qqen > "$tmpnative"
pacman --config "$tmpconf" -Qqem > "$tmpforeign"

grep -vxF -f "$tmpexclude" "$tmpnative" > "$dir/pacman.txt" || true
grep -vxF -f "$tmpexclude" "$tmpforeign" > "$dir/aur.txt" || true

printf '%s\n' cider > "$dir/cider.txt"

echo "pacman.txt: $(wc -l < "$dir/pacman.txt") packages"
echo "aur.txt:    $(wc -l < "$dir/aur.txt") packages"
echo "cider.txt:  $(wc -l < "$dir/cider.txt") packages"
