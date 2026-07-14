#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOG="$ROOT/mvp-check.log"
: > "$LOG"
say(){ printf '%s\n' "[mvp] $*" | tee -a "$LOG"; }
run(){ say "$*"; "$@" 2>&1 | tee -a "$LOG"; }
status=0
run make kernel || status=1
run make cactus-download || status=1
run make eval || status=1
run make boot-smoke || status=1
run make usb-tree || status=1
run make usb-image || true
run make portable-usb || status=1
ART="$ROOT/ai-pid1-usb.tar.gz"
[ -s "$ART" ] || { say "missing $ART"; status=1; }
[ -s "$ROOT/rootfs.cpio.gz" ] || { say "missing rootfs.cpio.gz"; status=1; }
[ -s "$ROOT/ai-cortex-usb.tar.gz" ] || { say "missing ai-cortex-usb.tar.gz"; status=1; }
if [ -f "$ROOT/boot-smoke.log" ] && grep -q '\[init\] boot' "$ROOT/boot-smoke.log"; then say "real qemu boot: PASS"; else say "real qemu boot: NOT_PROVEN_ON_THIS_HOST"; fi
if [ "$status" = 0 ]; then say "MVP-1.0 READY FOR TESTING"; else say "MVP-1.0 CHECK FAILED"; fi
exit "$status"
