#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BB="$ROOT/rootfs/bin/busybox"
mkdir -p "$ROOT/rootfs/bin" "$ROOT/rootfs/sbin" "$ROOT/rootfs/usr/bin" "$ROOT/rootfs/usr/sbin"
say(){ printf '%s\n' "[busybox] $*"; }
if command -v busybox >/dev/null 2>&1; then
  say "using host busybox: $(command -v busybox)"
  cp "$(command -v busybox)" "$BB"
else
  arch="$(uname -m 2>/dev/null || echo x86_64)"
  case "$arch" in
    x86_64|amd64) url=https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox;;
    i386|i686) url=https://busybox.net/downloads/binaries/1.35.0-i686-linux-musl/busybox;;
    *) url=https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox; say "no upstream static busybox for $arch here; downloading x86_64 for qemu/x86 images";;
  esac
  say "download $url"
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$BB"; else wget -qO "$BB" "$url"; fi
fi
chmod +x "$BB"
for x in sh ash mount umount ps tail cat echo true false sleep mkdir mknod ln ls dmesg ip ifconfig route hostname env printf kill sync reboot poweroff; do ln -sf /bin/busybox "$ROOT/rootfs/bin/$x"; done
for x in init halt; do ln -sf /bin/busybox "$ROOT/rootfs/sbin/$x"; done
say "installed $BB"
