# ai-pid1

Deterministic C PID1 plus memory-safe Rust Cortex supervisor. AI/control is not PID1; PID1 is only init, mount, console, reap, launch, restart.

```text
kernel -> /init PID1
  ├─ mount /proc /sys /dev /run /tmp
  ├─ configure /dev/console
  ├─ reap children
  ├─ launch net/storage hooks
  ├─ launch watchdog
  └─ launch/restart /sbin/cortex
        ├─ observe /proc
        ├─ select bounded allowlisted tools
        ├─ execute verify/start/stop/restart/log only
        └─ journal to /var/lib/cortex/journal.jsonl
```

Build/package:

```sh
make install cpio
```

Boot example:

```sh
qemu-system-x86_64 -kernel bzImage -initrd rootfs.cpio.gz -append 'console=ttyS0 rdinit=/init' -nographic
```

Note: the rootfs still needs a shell/busybox for tool execution (`/bin/sh`, `ps`, `tail`) in a real initramfs.
