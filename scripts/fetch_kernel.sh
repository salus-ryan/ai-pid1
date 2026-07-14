#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ARCH="${AI_PID1_KERNEL_ARCH:-x86_64}"
OUT="${AI_PID1_KERNEL_OUT:-$ROOT/kernels/$ARCH/vmlinuz}"
say(){ printf '%s\n' "[kernel] $*"; }
mkdir -p "$(dirname "$OUT")"
if [ -n "${AI_PID1_KERNEL:-}" ] && [ -f "$AI_PID1_KERNEL" ]; then cp "$AI_PID1_KERNEL" "$OUT"; say "copied $AI_PID1_KERNEL -> $OUT"; exit 0; fi
if [ -s "$OUT" ]; then say "exists $OUT"; exit 0; fi
case "$ARCH" in
  x86_64|amd64) URL="${AI_PID1_KERNEL_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/netboot/vmlinuz-lts}";;
  aarch64|arm64) URL="${AI_PID1_KERNEL_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/netboot/vmlinuz-lts}";;
  *) say "unsupported arch=$ARCH; set AI_PID1_KERNEL_URL"; exit 2;;
esac
say "download $URL"
if command -v curl >/dev/null 2>&1; then curl -fL "$URL" -o "$OUT"; else wget -O "$OUT" "$URL"; fi
chmod 0644 "$OUT"
say "OK $OUT"
