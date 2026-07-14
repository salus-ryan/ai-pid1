# MVP-1.0 Ready for Testing

This repository now produces a testable native-AI PID1 prototype.

## What is included

- Deterministic C `/init` PID1
- Rust `/sbin/cortex` safety supervisor
- Rust `/sbin/cactus-modeld` model sidecar over Unix socket
- Bundled `/opt/cactus-needle-decider` bridge
- Cactus + Needle source/assets downloader
- BusyBox-based initramfs userspace
- Auto kernel fetch for x86_64 test path
- USB boot tree / optional GRUB rescue ISO builder
- Eval suite and MVP check target

## Fast test path on Windows

PowerShell:

```powershell
irm https://raw.githubusercontent.com/salus-ryan/ai-pid1/master/bootstrap-windows.ps1 | iex
```

This installs/uses WSL Ubuntu and runs the Linux bootstrap inside it.

## Fast test path on x86_64 Linux/WSL

```sh
git clone https://github.com/salus-ryan/ai-pid1.git
cd ai-pid1
make mvp
```

Expected minimum success:

```text
MVP-1.0 READY FOR TESTING
```

If `qemu-system-x86_64` is installed and host/userland arch matches, `make boot-smoke` attempts a real kernel+initramfs boot and checks for:

```text
[init] boot
```

## Termux / non-x86_64 note

Termux/aarch64 can build package artifacts and run evals, but real x86_64 boot is skipped unless you provide a matching cross-compiled userspace/kernel or run on x86_64.

## Main artifact

```text
rootfs.cpio.gz
ai-pid1-usb.tar.gz
```

Optional if GRUB tooling exists:

```text
ai-pid1-usb.iso
```
