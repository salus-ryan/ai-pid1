#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="${AI_CORTEX_USB_TREE:-$ROOT/ai-cortex-usb}"
IMG="${AI_CORTEX_USB_IMG:-$ROOT/ai-cortex-usb.img}"
SIZE="${AI_CORTEX_USB_SIZE:-512M}"
say(){ printf '%s\n' "[portable-usb] $*"; }
(cd "$ROOT" && make cpio >/dev/null)
K="${AI_PID1_KERNEL:-$ROOT/kernels/${AI_PID1_KERNEL_ARCH:-x86_64}/vmlinuz}"
[ -s "$K" ] || (cd "$ROOT" && make kernel >/dev/null)
[ -s "$K" ] || { say "missing kernel; set AI_PID1_KERNEL=/path/to/vmlinuz"; exit 2; }
rm -rf "$OUT"
mkdir -p "$OUT/EFI/BOOT" "$OUT/boot/grub" "$OUT/boot/x86_64" "$OUT/cortex/state" "$OUT/cortex/models" "$OUT/cortex/policy"
cp "$K" "$OUT/boot/x86_64/vmlinuz"
cp "$ROOT/rootfs.cpio.gz" "$OUT/boot/x86_64/rootfs.cpio.gz"
cp "$ROOT/rootfs/etc/cortex/policy.json" "$OUT/cortex/policy/policy.json" 2>/dev/null || true
[ -f "$ROOT/CORTEX_CAPSULE.json" ] || (cd "$ROOT" && make capsule >/dev/null)
cp "$ROOT/CORTEX_CAPSULE.json" "$OUT/cortex/CORTEX_CAPSULE.json"
cat > "$OUT/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0
menuentry "Cortex AI Native OS (x86_64)" {
    linux /boot/x86_64/vmlinuz console=tty0 console=ttyS0 rdinit=/init panic=1 CORTEX_STATE_DEV=auto
    initrd /boot/x86_64/rootfs.cpio.gz
}
menuentry "Cortex AI Native OS (serial debug)" {
    linux /boot/x86_64/vmlinuz console=ttyS0 rdinit=/init panic=1 loglevel=7 CORTEX_STATE_DEV=auto
    initrd /boot/x86_64/rootfs.cpio.gz
}
EOF
cat > "$OUT/README.txt" <<'EOF'
Cortex AI Native OS portable USB tree

This is consent-based boot media. It does not autorun or affect a running host OS.
Boot requires selecting the USB device in firmware/boot menu.

Layout:
  EFI/BOOT/BOOTX64.EFI       UEFI GRUB loader, if generated
  boot/x86_64/vmlinuz        Linux kernel
  boot/x86_64/rootfs.cpio.gz Cortex PID1 initramfs
  cortex/state               persistent state placeholder
  cortex/models              model asset placeholder
  cortex/policy              Cortex policy
  cortex/CORTEX_CAPSULE.json Boot/action contract and artifact hashes

If BOOTX64.EFI is missing, install grub tools and rerun make portable-usb.
EOF
cat > "$OUT/EFI/BOOT/STARTUP.NSH" <<'EOF'
BOOTX64.EFI
EOF
if command -v grub-mkstandalone >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  cat > "$TMP/early.cfg" <<'EOF'
search --file --set=root /boot/grub/grub.cfg
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EOF
  say "building EFI/BOOT/BOOTX64.EFI"
  grub-mkstandalone -O x86_64-efi -o "$OUT/EFI/BOOT/BOOTX64.EFI" "boot/grub/grub.cfg=$TMP/early.cfg"
  rm -rf "$TMP"
else
  say "SKIP BOOTX64.EFI: install grub-mkstandalone/grub-efi tools"
  echo "missing grub-mkstandalone" > "$OUT/EFI/BOOT/BOOTX64.EFI.MISSING"
fi
(cd "$ROOT" && tar -czf ai-cortex-usb.tar.gz "$(basename "$OUT")")
say "tree=$OUT tar=$ROOT/ai-cortex-usb.tar.gz"
if command -v mformat >/dev/null 2>&1 && command -v mcopy >/dev/null 2>&1 && [ ! -e "$OUT/EFI/BOOT/BOOTX64.EFI.MISSING" ]; then
  say "building FAT32 superfloppy image $IMG size=$SIZE"
  rm -f "$IMG"; truncate -s "$SIZE" "$IMG"; mformat -i "$IMG" -F ::
  (cd "$OUT" && find . -type d | while read d; do [ "$d" = "." ] || mmd -i "$IMG" "::/${d#./}" 2>/dev/null || true; done)
  (cd "$OUT" && find . -type f | while read f; do mcopy -i "$IMG" "$f" "::/${f#./}"; done)
  say "image=$IMG"
else
  say "SKIP image: need mtools (mformat,mcopy) and BOOTX64.EFI. Tree/tar are ready."
fi
