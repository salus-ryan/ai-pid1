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

```sh
curl -fsSL https://raw.githubusercontent.com/salus-ryan/ai-pid1/master/bootstrap.sh | sh
```

Mobile-safe:

```sh
u=https://raw.githubusercontent.com
r=salus-ryan/ai-pid1
b=master/bootstrap.sh
curl -fsSL "$u/$r/$b" | sh
```

## Cortex AI hook

Cortex is the safety wrapper. `/sbin/cactus-modeld` is the model sidecar. A model may propose JSON actions, but Cortex validates them before execution.

Run the model sidecar:

```sh
CORTEX_MODEL_SOCK=/run/cortex-model.sock /sbin/cactus-modeld
CORTEX_SOCK=/run/cortex-model.sock /sbin/cortex
```

`cactus-modeld` can delegate to a native Cactus/Needle command:

```sh
CORTEX_CACTUS_CMD='/opt/cactus-needle-decider' /sbin/cactus-modeld
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

The eval suite tests heartbeat fallback, model action execution, policy denial, service allowlists, path traversal denial, max-action truncation, bad-model-output fallback, Cactus asset presence, and the Cactus decider shim. Results are written to `eval-results.json`.

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
