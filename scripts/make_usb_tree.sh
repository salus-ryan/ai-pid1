#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="${AI_PID1_USB_TREE:-$ROOT/ai-pid1-usb}"
K="${AI_PID1_KERNEL:-}"
say(){ printf '%s\n' "[usb-tree] $*"; }
find_kernel(){
  [ -n "$K" ] && [ -f "$K" ] && { printf '%s\n' "$K"; return 0; }
  for x in /boot/vmlinuz-$(uname -r 2>/dev/null) /boot/vmlinuz /boot/bzImage "$ROOT/bzImage" "$ROOT/vmlinuz"; do
    [ -f "$x" ] && { printf '%s\n' "$x"; return 0; }
  done
  return 1
}
(cd "$ROOT" && make cpio >/dev/null)
rm -rf "$OUT"; mkdir -p "$OUT/boot/grub"
cp "$ROOT/rootfs.cpio.gz" "$OUT/boot/ai-pid1.cpio.gz"
if KP="$(find_kernel)"; then
  say "kernel=$KP"; cp "$KP" "$OUT/boot/vmlinuz"
else
  say "no kernel found; put one at $OUT/boot/vmlinuz or rerun with AI_PID1_KERNEL=/path/to/vmlinuz"
  printf 'PLACEHOLDER: copy Linux kernel here as vmlinuz\n' > "$OUT/boot/vmlinuz.MISSING"
fi
cat > "$OUT/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0
menuentry "AI PID1" {
    linux /boot/vmlinuz console=tty0 console=ttyS0 rdinit=/init panic=1
    initrd /boot/ai-pid1.cpio.gz
}
EOF
cat > "$OUT/README.txt" <<'EOF'
AI PID1 USB tree

Files:
  boot/vmlinuz             Linux kernel; required
  boot/ai-pid1.cpio.gz     AI PID1 initramfs
  boot/grub/grub.cfg       GRUB boot menu

If vmlinuz.MISSING exists, copy a kernel to boot/vmlinuz.
To create a dd-able ISO on Linux with grub-mkrescue+xorriso:
  grub-mkrescue -o ai-pid1-usb.iso ai-pid1-usb
EOF
(cd "$ROOT" && tar -czf ai-pid1-usb.tar.gz "$(basename "$OUT")")
say "OK tree=$OUT tar=$ROOT/ai-pid1-usb.tar.gz"
