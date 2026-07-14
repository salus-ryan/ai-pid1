#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TREE="${AI_PID1_USB_TREE:-$ROOT/ai-pid1-usb}"
ISO="${AI_PID1_USB_ISO:-$ROOT/ai-pid1-usb.iso}"
say(){ printf '%s\n' "[usb-image] $*"; }
sh "$ROOT/scripts/make_usb_tree.sh"
if [ -e "$TREE/boot/vmlinuz.MISSING" ]; then
  say "SKIP image: missing kernel. Set AI_PID1_KERNEL=/path/to/vmlinuz"
  exit 0
fi
if command -v grub-mkrescue >/dev/null 2>&1; then
  say "grub-mkrescue -> $ISO"
  grub-mkrescue -o "$ISO" "$TREE"
  say "OK iso=$ISO"
  exit 0
fi
if command -v xorriso >/dev/null 2>&1; then
  say "xorriso present but grub-mkrescue missing; cannot install GRUB boot image automatically"
fi
say "SKIP image: install grub-mkrescue + xorriso, then rerun. USB tree/tar are ready."
exit 0
