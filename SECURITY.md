# Security Model

ai-pid1 is consent-based boot media. It does not autorun, exploit, persist in a host OS, or bypass firmware controls. A user must explicitly boot a device from the USB/drive.

## Trust boundaries

```text
firmware boot choice -> Linux kernel -> /init PID1 -> cortex -> bounded tools
                                      -> cactus-modeld -> model proposals
```

The model proposes actions. Cortex validates actions against policy before execution.

## Hardening currently implemented

- AI/model is not PID1; PID1 is small deterministic C.
- Cortex is memory-safe Rust.
- Model runs out-of-process as `cactus-modeld`.
- Unix-socket model IPC.
- JSON action schema: `{tool,arg,why}`.
- Tool allowlist: `verify`, `start`, `stop`, `restart`, `log`.
- Service allowlist: default `net`, `storage`.
- Log path traversal denial.
- Shell metacharacter denial for `verify`.
- Verify command prefix allowlist.
- Max action count per loop.
- Max argument length.
- Per-tool timeout with process kill.
- Journal of every allowed/denied action.
- Safe fallback if model output is invalid/unavailable.
- Eval coverage for policy denial and timeout behavior.

## Non-goals

- No host OS takeover.
- No Secure Boot bypass.
- No persistence on internal disks unless explicitly configured.
- No hidden network service by default.

## Next hardening targets

- Signed boot artifacts / Secure Boot enrollment path.
- Read-only root with explicit persistent state partition.
- Per-service restart budgets/cooldowns.
- Rollback snapshots before config mutation.
- Authenticated modeld socket.
- TPM/measured boot support where available.
