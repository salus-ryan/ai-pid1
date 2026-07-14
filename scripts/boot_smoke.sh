#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
say(){ printf '%s\n' "[boot-smoke] $*"; }
[ -f "$ROOT/rootfs.cpio.gz" ] || (cd "$ROOT" && make cpio)
if command -v unshare >/dev/null 2>&1 && [ "${AI_PID1_UNSHARE:-0}" = 1 ]; then
  say "trying PID namespace smoke via unshare"
  timeout 8 unshare -fp --mount-proc "$ROOT/rootfs/init" || true
fi
K="${AI_PID1_KERNEL:-$ROOT/bzImage}"
if command -v qemu-system-x86_64 >/dev/null 2>&1 && [ -f "$K" ]; then
  host="$(uname -m 2>/dev/null || echo unknown)"; if [ "$host" != x86_64 ] && [ "${AI_PID1_ALLOW_CROSS_BOOT:-0}" != 1 ]; then say "SKIP qemu: host-built init/cortex are $host, kernel is x86_64. Build on x86_64 Linux or set AI_PID1_ALLOW_CROSS_BOOT=1 if cross-built."; exit 0; fi
  LOG="$ROOT/boot-smoke.log"; rm -f "$LOG"
  say "qemu x86_64 kernel=$K"
  timeout 20 qemu-system-x86_64 -m 256M -kernel "$K" -initrd "$ROOT/rootfs.cpio.gz" -append 'console=ttyS0 rdinit=/init panic=1' -nographic >"$LOG" 2>&1 || true
  grep -q '\[init\] boot' "$LOG" && { say "PASS qemu reached PID1"; exit 0; }
  say "FAIL qemu did not reach PID1; see $LOG"; exit 1
fi
say "SKIP: provide qemu-system-x86_64 and AI_PID1_KERNEL=/path/to/bzImage for real boot smoke"
say "cpio contents check"
gzip -t "$ROOT/rootfs.cpio.gz"
[ -x "$ROOT/rootfs/init" ] && [ -x "$ROOT/rootfs/sbin/cortex" ] && [ -x "$ROOT/rootfs/sbin/cactus-modeld" ] && [ -x "$ROOT/rootfs/bin/busybox" ]
say "PASS package smoke"
