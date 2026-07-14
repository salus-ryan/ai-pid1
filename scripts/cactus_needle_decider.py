#!/usr/bin/env python3
"""Needle decider for Cortex.
Reads Cortex state JSON on stdin and returns Cortex action JSON on stdout.
If Needle/JAX/checkpoint are present, runs real Needle generation. Otherwise it
returns a safe fallback action. Set CORTEX_NEEDLE_MOCK to JSON for deterministic evals.
"""
import json, os, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1] if 'scripts' in str(Path(__file__).resolve()) else Path('/')
TOOLS=json.dumps([
 {"name":"cortex_verify","description":"Run a non-mutating verification command.","parameters":{"cmd":{"type":"string","description":"safe shell command","required":True}}},
 {"name":"cortex_restart_service","description":"Restart an allowlisted service only when clearly failed.","parameters":{"service":{"type":"string","description":"net or storage","required":True}}},
 {"name":"cortex_log","description":"Read an allowlisted log file basename.","parameters":{"file":{"type":"string","description":"log basename","required":True}}}
])
def emit(actions): print(json.dumps(actions,separators=(',',':')))
def fallback(why='needle-fallback'): emit([{"tool":"verify","arg":"true","why":why}])
def map_call(c):
    name=c.get('name',''); a=c.get('arguments') or {}
    if name=='cortex_verify': return {"tool":"verify","arg":str(a.get('cmd','true')),"why":"needle"}
    if name=='cortex_restart_service': return {"tool":"restart","arg":str(a.get('service','')),"why":"needle"}
    if name=='cortex_log': return {"tool":"log","arg":str(a.get('file','')),"why":"needle"}
    return None
def main():
    raw=sys.stdin.read() or '{}'
    if os.environ.get('CORTEX_NEEDLE_MOCK'):
        json.loads(raw); emit(json.loads(os.environ['CORTEX_NEEDLE_MOCK'])); return
    try: state=json.loads(raw)
    except Exception: fallback('needle-bad-state'); return
    ck=os.environ.get('CORTEX_NEEDLE_CHECKPOINT')
    candidates=[ck] if ck else [str(ROOT/'third_party/needle-hf/needle.pkl'), str(ROOT/'third_party/needle/checkpoints/needle.pkl'), '/opt/needle/needle.pkl']
    checkpoint=next((x for x in candidates if x and Path(x).exists()), None)
    if not checkpoint: fallback('needle-missing-checkpoint'); return
    try:
        needle_repo=os.environ.get('CORTEX_NEEDLE_REPO', str(ROOT/'third_party/needle'))
        if Path(needle_repo).exists(): sys.path.insert(0, needle_repo)
        from needle import SimpleAttentionNetwork, load_checkpoint, generate, get_tokenizer
        params, config = load_checkpoint(checkpoint)
        model = SimpleAttentionNetwork(config)
        q=("You are Cortex PID1 supervisor policy. Choose at most one safe tool call. "
           "Prefer cortex_verify unless a clearly failed allowlisted service needs restart. "
           "State JSON: "+json.dumps(state)[:6000])
        out=generate(model, params, get_tokenizer(), query=q, tools=TOOLS, stream=False)
        calls=json.loads(out) if isinstance(out,str) else out
        acts=[x for x in (map_call(c) for c in calls) if x]
        emit(acts[:1] or [{"tool":"verify","arg":"true","why":"needle-empty"}])
    except Exception as e:
        fallback('needle-error:'+type(e).__name__)
if __name__=='__main__': main()
