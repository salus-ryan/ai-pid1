#!/usr/bin/env python3
"""Cortex decider shim for Cactus/Needle.
Reads Cortex state JSON on stdin. If CORTEX_CACTUS_CMD is set, it sends the state
JSON to that command and expects action JSON back. Otherwise it emits a safe
heartbeat so Cortex can be evaluated without native Cactus bindings.
"""
import json, os, subprocess, sys
state=sys.stdin.read()
cmd=os.environ.get('CORTEX_CACTUS_CMD')
if cmd:
    p=subprocess.run(cmd,shell=True,input=state,text=True,capture_output=True,timeout=int(os.environ.get('CORTEX_CACTUS_TIMEOUT','10')))
    if p.returncode==0:
        try:
            actions=json.loads(p.stdout)
            assert isinstance(actions,list)
            print(json.dumps(actions)); sys.exit(0)
        except Exception as e:
            print(json.dumps([{"tool":"verify","arg":"true","why":"cactus-invalid-output-fallback"}]))
            sys.exit(0)
    print(json.dumps([{"tool":"verify","arg":"true","why":"cactus-error-fallback"}]))
else:
    # TODO: wire direct Cactus runtime/Needle bindings here when available.
    json.loads(state or '{}')
    print(json.dumps([{"tool":"verify","arg":"true","why":"cactus-shim-heartbeat"}]))
