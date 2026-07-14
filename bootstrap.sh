#!/usr/bin/env sh
set -eu
REPO="https://github.com/salus-ryan/ai-pid1.git"
DIR="${AI_PID1_DIR:-ai-pid1}"
BRANCH="${AI_PID1_BRANCH:-master}"
need(){ command -v "$1" >/dev/null 2>&1; }
say(){ printf '%s\n' "[ai-pid1] $*"; }
run(){ say "$*"; "$@"; }
os(){ case "$(uname -s 2>/dev/null || echo unknown)" in Linux*) echo linux;; Darwin*) echo mac;; MINGW*|MSYS*|CYGWIN*) echo windows-sh;; *) echo unknown;; esac; }
install_deps(){
  missing=""; for x in git make cc cargo rustc cpio gzip; do need "$x" || missing="$missing $x"; done
  [ -z "$missing" ] && return 0
  say "missing:$missing"
  if [ -n "${PREFIX:-}" ] && echo "${PREFIX:-}" | grep -q 'com.termux'; then
    run pkg update -y; run pkg install -y git make clang rust cpio gzip
  elif need apt-get; then
    SUDO=""; [ "$(id -u)" != 0 ] && SUDO=sudo
    run $SUDO apt-get update; run $SUDO apt-get install -y git make clang rustc cargo cpio gzip
  elif need dnf; then
    SUDO=""; [ "$(id -u)" != 0 ] && SUDO=sudo
    run $SUDO dnf install -y git make clang rust cargo cpio gzip
  elif need pacman; then
    SUDO=""; [ "$(id -u)" != 0 ] && SUDO=sudo
    run $SUDO pacman -Sy --needed --noconfirm git make clang rust cpio gzip
  elif need apk; then
    SUDO=""; [ "$(id -u)" != 0 ] && SUDO=sudo
    run $SUDO apk add git make clang rust cargo cpio gzip musl-dev
  elif need brew; then
    run brew install git make llvm rust cpio gzip || true
  else
    say "No supported package manager found. Install: git make C compiler rust/cargo cpio gzip"
  fi
}
clone_or_update(){
  if [ -d .git ] && git remote -v 2>/dev/null | grep -q 'salus-ryan/ai-pid1'; then return 0; fi
  if [ -d "$DIR/.git" ]; then cd "$DIR"; run git pull --ff-only || true; return 0; fi
  run git clone --branch "$BRANCH" "$REPO" "$DIR"; cd "$DIR"
}
main(){
  O="$(os)"; say "platform=$O"
  if [ "$O" = windows-sh ]; then say "Windows detected: run in WSL for kernel/initramfs builds; Git-Bash/MSYS may only clone."; fi
  install_deps
  clone_or_update
  run make test
  run make cpio
  say "OK: $(pwd)/rootfs.cpio.gz"
}
main "$@"
