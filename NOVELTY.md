# What makes ai-pid1 novel

The project is not merely "an LLM as init". The novel unit is a **Boot Capsule**:

a consent-booted, removable AI-native OS whose deterministic PID1 launches a local model sidecar, while a Rust supervisor validates every model-proposed system action against a cryptographic boot/action contract.

## Core pattern

```text
Boot Capsule = boot graph + policy + model sidecar + action schema + hashes + receipts
```

Runtime thesis:

```text
model proposes → Cortex validates → bounded tool executes/denies → receipt is journaled
```

## Distinctive properties

- AI is native to the OS control plane, not an app on top of an OS.
- The model is not PID1; deterministic PID1 supervises the model.
- Model output is treated as untrusted input.
- The OS is portable/removable and consent-booted.
- A machine-readable `CORTEX_CAPSULE.json` declares the boot graph, safety invariants, policy/action schema, and artifact hashes.
- Eval suite tests safety boundaries, not just happy-path boot.

## Positioning

Good phrase:

> AI-native initramfs OS with a verifiable boot capsule and policy-gated local model control plane.

Avoid:

> AI virus, AI rootkit, LLM literally replacing init.
