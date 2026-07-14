# ai-pid1

Deterministic C PID1 plus memory-safe Rust Cortex supervisor. AI/control is not PID1; PID1 only mounts, consoles, reaps, launches, restarts.

```text
kernel -> /init PID1
  ├─ mount /proc /sys /dev /run /tmp
  ├─ configure /dev/console
  ├─ reap children
  ├─ launch net/storage hooks
  ├─ launch watchdog
  ├─ launch /sbin/cactus-modeld
  └─ launch/restart /sbin/cortex
        ├─ observe /proc
        ├─ ask cactus-modeld over /run/cortex-model.sock
        ├─ validate bounded actions against /etc/cortex/policy.json
        ├─ execute allowlisted verify/start/stop/restart/log
        └─ journal to /var/lib/cortex/journal.jsonl
```

## Build

Linux/macOS/Termux:

```sh
curl -fsSL https://raw.githubusercontent.com/salus-ryan/ai-pid1/master/bootstrap.sh | sh
```

Windows PowerShell bootstrap, including WSL install/use:

```powershell
irm https://raw.githubusercontent.com/salus-ryan/ai-pid1/master/bootstrap-windows.ps1 | iex
```

Mobile-safe:

```sh
u=https://raw.githubusercontent.com
r=salus-ryan/ai-pid1
b=master/bootstrap.sh
curl -fsSL "$u/$r/$b" | sh
```

## Atomic Mail bridge

Atomic Mail webhooks/WebSockets are not live yet, so this repo includes a polling bridge that behaves like a webhook source:

```sh
# print new messages as JSON
./scripts/atomic_mail_bridge.py

# or POST each new message to your endpoint
ATOMIC_MAIL_WEBHOOK_URL=https://example.com/hook ./scripts/atomic_mail_bridge.py

# one-shot test
./scripts/atomic_mail_bridge.py --once
```

Configure:

```sh
ATOMIC_MAIL_POLL_SECONDS=30
ATOMIC_MAIL_CREDENTIALS_DIR=$PWD/.atomicmail
```

## Cortex AI hook

Cortex is the safety wrapper. `/sbin/cactus-modeld` is the model sidecar. A model may propose JSON actions, but Cortex validates them before execution.

Run the model sidecar:

```sh
CORTEX_MODEL_SOCK=/run/cortex-model.sock /sbin/cactus-modeld
CORTEX_SOCK=/run/cortex-model.sock /sbin/cortex
```

`cactus-modeld` delegates to the bundled Needle decider by default in PID1:

```sh
CORTEX_CACTUS_CMD=/opt/cactus-needle-decider /sbin/cactus-modeld
```

For real Needle inference, download weights and provide Python/JAX Needle deps:

```sh
AI_PID1_CACTUS_FULL=1 make cactus-download
CORTEX_NEEDLE_CHECKPOINT=$PWD/third_party/needle-hf/needle.pkl \
CORTEX_CACTUS_CMD=$PWD/scripts/cactus_needle_decider.py \
/sbin/cactus-modeld
```

The command receives state JSON on stdin and must return:

```json
[{"tool":"verify","arg":"true","why":"heartbeat"}]
```

Allowed actions are controlled by `/etc/cortex/policy.json`.

## Cactus / Needle assets

Bootstrap downloads Cactus + Needle source into `third_party/` and small Needle HF assets into `third_party/needle-hf/`.

```sh
make cactus-download
```

Set `AI_PID1_CACTUS_FULL=1` to also download full model weights (`model.safetensors`, `needle.pkl`).

## Eval

```sh
make cactus-download eval
# or
./eval.sh
```

The eval suite tests heartbeat fallback, model action execution, policy denial, service allowlists, path traversal denial, dangerous shell denial, per-tool timeout enforcement, max-action truncation, bad-model-output fallback, Cactus asset presence, the Cactus decider shim, modeld socket IPC, Needle decider fallback/mock/delegation paths, BusyBox bundling, USB boot tree generation, and portable Cortex USB tree generation. Results are written to `eval-results.json`.

See [`SECURITY.md`](SECURITY.md) for the consent-based boot and Cortex hardening model.

## Portable USB-C AI-native OS

Build the consent-based portable Cortex OS tree:

```sh
make portable-usb
```

Outputs:

```text
ai-cortex-usb/
ai-cortex-usb.tar.gz
ai-cortex-usb.img   # only when GRUB EFI + mtools are available
```

This does not autorun and does not affect a running host OS. A device must be explicitly booted from the USB drive by firmware/boot menu. Current target is x86_64 UEFI. ARM64/Raspberry Pi/Apple Silicon need separate boot builds.

## USB / drive boot artifacts

Build a USB boot tree and tarball:

```sh
make usb-tree
```

Outputs:

```text
ai-pid1-usb/
ai-pid1-usb.tar.gz
```

Fetch a known Linux kernel automatically:

```sh
make kernel
```

Or provide one:

```sh
AI_PID1_KERNEL=/path/to/vmlinuz make usb-tree
```

Fastest MVP-1.0 path is an x86_64 Linux/WSL host:

```sh
git clone https://github.com/salus-ryan/ai-pid1.git
cd ai-pid1
make mvp
```

Equivalent expanded path:

```sh
make kernel cactus-download eval boot-smoke usb-image
```

Build a dd-able GRUB rescue ISO when `grub-mkrescue` + `xorriso` are installed:

```sh
AI_PID1_KERNEL=/path/to/vmlinuz make usb-image
sudo dd if=ai-pid1-usb.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Be careful: `/dev/sdX` must be the whole USB drive, not your system disk.

## Boot smoke / BusyBox

Bundle a minimal userspace:

```sh
make busybox
```

Package and smoke-test:

```sh
make boot-smoke
```

If `qemu-system-x86_64` and a kernel are available, set:

```sh
AI_PID1_KERNEL=/path/to/bzImage make boot-smoke
```

Otherwise the smoke test verifies initramfs contents and gzip integrity.

## Package

```sh
make test cpio
```

Output:

```text
rootfs.cpio.gz
```

Boot example:

```sh
qemu-system-x86_64 -kernel bzImage -initrd rootfs.cpio.gz -append 'console=ttyS0 rdinit=/init' -nographic
```

Note: real initramfs still needs `/bin/sh`/busybox for tool execution.
