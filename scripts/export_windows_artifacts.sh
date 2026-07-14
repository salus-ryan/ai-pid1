#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
say(){ printf '%s\n' "[export] $*"; }
if [ -n "${AI_PID1_EXPORT_DIR:-}" ]; then OUT="$AI_PID1_EXPORT_DIR";
elif [ -d /mnt/c/Users ]; then
  WINUSER="${AI_PID1_WINDOWS_USER:-}"
  if [ -z "$WINUSER" ]; then WINUSER="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r' || true)"; fi
  if [ -n "$WINUSER" ] && [ -d "/mnt/c/Users/$WINUSER/Desktop" ]; then OUT="/mnt/c/Users/$WINUSER/Desktop/ai-pid1-artifacts"; else OUT="$ROOT/artifacts"; fi
else OUT="$ROOT/artifacts"; fi
mkdir -p "$OUT"
for f in rootfs.cpio.gz ai-pid1-usb.tar.gz ai-pid1-usb.iso mvp-check.log boot-smoke.log eval-results.json; do [ -f "$ROOT/$f" ] && cp -f "$ROOT/$f" "$OUT/"; done
cat > "$OUT/README.txt" <<'EOF'
ai-pid1 artifacts

Files:
  rootfs.cpio.gz       initramfs with /init, cortex, cactus-modeld, busybox
  ai-pid1-usb.tar.gz   boot tree archive
  ai-pid1-usb.iso      bootable ISO if generated
  eval-results.json    eval suite results
  mvp-check.log        MVP build log
  boot-smoke.log       QEMU boot log if real boot ran

If ai-pid1-usb.iso exists, write it to USB from Windows using Rufus or balenaEtcher.
If it does not exist, run inside Ubuntu/WSL: sudo apt install -y grub-common xorriso mtools && make usb-image export-artifacts
EOF
say "OK $OUT"
ls -lh "$OUT" || true
