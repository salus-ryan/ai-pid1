#!/usr/bin/env python3
import hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def h(p):
    p=Path(p)
    if not p.exists() or not p.is_file(): return None
    x=hashlib.sha256();
    with p.open('rb') as f:
        for b in iter(lambda:f.read(65536),b''): x.update(b)
    return x.hexdigest()
def git(cmd):
    try:return subprocess.check_output(['git']+cmd,cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
    except Exception:return None
files=['src/init.c','cortex-rs/src/main.rs','cortex-rs/src/bin/cactus-modeld.rs','rootfs/etc/cortex/policy.json','scripts/cactus_needle_decider.py','scripts/make_portable_usb.sh']
capsule={
 'schema':'cortex.boot-capsule.v1',
 'name':'ai-pid1-cortex',
 'generated_at':int(time.time()),
 'git':{'commit':git(['rev-parse','HEAD']),'dirty':bool(git(['status','--porcelain']))},
 'thesis':'deterministic PID1 supervises a local AI sidecar; model proposes, Cortex validates, every action receives a journaled receipt',
 'consent_boundary':'runs only when firmware/user explicitly boots this media; no host-OS autorun or persistence',
 'boot_graph':['firmware','EFI/GRUB','Linux kernel','/init PID1','/sbin/cactus-modeld','/sbin/cortex','bounded tools'],
 'action_schema':{'tool':'verify|start|stop|restart|log','arg':'policy-bounded string','why':'human/model-readable reason'},
 'safety_invariants':['model is never PID1','PID1 does no inference','model output is untrusted','policy validates before execution','denied actions are journaled','tool execution is timeout-bounded'],
 'hashes':{f:h(ROOT/f) for f in files},
 'artifacts':{f:h(ROOT/f) for f in ['rootfs.cpio.gz','ai-cortex-usb.tar.gz','ai-cortex-usb.img','ai-pid1-usb.iso']},
}
blob=json.dumps(capsule,sort_keys=True,separators=(',',':')).encode(); capsule['capsule_sha256']=hashlib.sha256(blob).hexdigest()
out=Path(os.environ.get('CORTEX_CAPSULE_OUT',ROOT/'CORTEX_CAPSULE.json'))
out.write_text(json.dumps(capsule,indent=2,sort_keys=True)+'\n')
print(out)
