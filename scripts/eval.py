#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, tempfile, textwrap, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'rootfs/sbin/cortex'
POLICY={"allow_tools":["verify","start","stop","restart","log"],"allow_services":["net","storage"],"max_actions":3,"loop_secs":1,"require_verify":False}
def run(cmd, **kw): return subprocess.run(cmd, text=True, capture_output=True, **kw)
def build():
    r=run(['make','install'], cwd=ROOT)
    if r.returncode: print(r.stdout+r.stderr); sys.exit(r.returncode)
def decider(tmp, actions=None, raw=None, rc=0):
    p=Path(tmp)/'decider.sh'
    if raw is None: raw=json.dumps(actions)
    p.write_text('#!/bin/sh\ncat >/dev/null\nprintf %s '+json.dumps(raw)+'\nexit '+str(rc)+'\n')
    p.chmod(0o755); return str(p)
def eval_case(name, actions=None, raw=None, rc=0, expect=None, policy=None):
    with tempfile.TemporaryDirectory(prefix='cortex-eval-') as td:
        st=Path(td)/'state'; st.mkdir(); pol=Path(td)/'policy.json'; pol.write_text(json.dumps(policy or POLICY))
        env=os.environ|{'CORTEX_STATE':str(st),'CORTEX_POLICY':str(pol),'CORTEX_ONCE':'1'}
        if actions is not None or raw is not None: env['CORTEX_DECIDER']=decider(td,actions,raw,rc)
        r=run([str(BIN)], env=env, timeout=10)
        journal=st/'journal.jsonl'; rows=[]
        if journal.exists(): rows=[json.loads(x) for x in journal.read_text().splitlines() if x.strip()]
        ok=expect(rows,r)
        return {'name':name,'ok':ok,'rows':rows,'rc':r.returncode,'stderr':r.stderr[-500:]}
def cactus_shim_case():
    with tempfile.TemporaryDirectory(prefix='cortex-eval-') as td:
        st=Path(td)/'state'; st.mkdir(); pol=Path(td)/'policy.json'; pol.write_text(json.dumps(POLICY))
        env=os.environ|{'CORTEX_STATE':str(st),'CORTEX_POLICY':str(pol),'CORTEX_ONCE':'1','CORTEX_DECIDER':str(ROOT/'scripts/cactus_decider.py')}
        r=run([str(BIN)], env=env, timeout=10)
        rows=[json.loads(x) for x in (st/'journal.jsonl').read_text().splitlines() if x.strip()]
        return {'name':'cactus decider shim emits safe action','ok':len(rows)==1 and rows[0]['allowed'] and rows[0]['action']['why']=='cactus-shim-heartbeat','rows':rows,'rc':r.returncode,'stderr':r.stderr[-500:]}

def modeld_socket_case():
    with tempfile.TemporaryDirectory(prefix='cortex-eval-') as td:
        sock=str(Path(td)/'model.sock'); st=Path(td)/'state'; st.mkdir(); pol=Path(td)/'policy.json'; pol.write_text(json.dumps(POLICY))
        md=subprocess.Popen([str(ROOT/'rootfs/sbin/cactus-modeld')], env=os.environ|{'CORTEX_MODEL_SOCK':sock}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            for _ in range(20):
                if Path(sock).exists(): break
                time.sleep(0.1)
            env=os.environ|{'CORTEX_STATE':str(st),'CORTEX_POLICY':str(pol),'CORTEX_ONCE':'1','CORTEX_SOCK':sock}
            r=run([str(BIN)], env=env, timeout=10)
            rows=[json.loads(x) for x in (st/'journal.jsonl').read_text().splitlines() if x.strip()]
            ok=len(rows)==1 and rows[0]['allowed'] and rows[0]['action']['why']=='modeld-heartbeat'
            return {'name':'cortex talks to cactus-modeld over unix socket','ok':ok,'rows':rows,'rc':r.returncode,'stderr':r.stderr[-500:]}
        finally:
            md.terminate();
            try: md.wait(timeout=2)
            except subprocess.TimeoutExpired: md.kill()

def cactus_assets_case():
    hf=ROOT/'third_party/needle-hf'
    files=['MANIFEST.json','README.md','config.json','tokenizer.model']
    ok=all((hf/f).exists() and (hf/f).stat().st_size>0 for f in files)
    return {'name':'cactus/needle assets downloaded','ok':ok,'rows':[], 'rc':0, 'stderr':'' if ok else 'run: make cactus-download'}


def needle_decider_fallback_case():
    with tempfile.TemporaryDirectory(prefix='cortex-eval-') as td:
        r=run([str(ROOT/'scripts/cactus_needle_decider.py')], input=json.dumps({'ps':'ok'}), timeout=10)
        try: acts=json.loads(r.stdout)
        except Exception: acts=[]
        ok=r.returncode==0 and acts and acts[0]['tool']=='verify' and acts[0]['arg']=='true'
        return {'name':'needle decider safe fallback','ok':ok,'rows':acts,'rc':r.returncode,'stderr':r.stderr[-500:]}

def needle_decider_mock_case():
    env=os.environ|{'CORTEX_NEEDLE_MOCK':json.dumps([{'tool':'restart','arg':'net','why':'mock'}])}
    r=run([str(ROOT/'scripts/cactus_needle_decider.py')], input=json.dumps({'ps':'net failed'}), env=env, timeout=10)
    try: acts=json.loads(r.stdout)
    except Exception: acts=[]
    ok=r.returncode==0 and acts==[{'tool':'restart','arg':'net','why':'mock'}]
    return {'name':'needle decider mock path returns actions','ok':ok,'rows':acts,'rc':r.returncode,'stderr':r.stderr[-500:]}

def modeld_uses_needle_decider_case():
    with tempfile.TemporaryDirectory(prefix='cortex-eval-') as td:
        sock=str(Path(td)/'model.sock'); st=Path(td)/'state'; st.mkdir(); pol=Path(td)/'policy.json'; pol.write_text(json.dumps(POLICY))
        cmd=str(ROOT/'scripts/cactus_needle_decider.py')
        env_md=os.environ|{'CORTEX_MODEL_SOCK':sock,'CORTEX_CACTUS_CMD':cmd,'CORTEX_NEEDLE_MOCK':json.dumps([{'tool':'restart','arg':'net','why':'mock'}])}
        md=subprocess.Popen([str(ROOT/'rootfs/sbin/cactus-modeld')], env=env_md, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            for _ in range(20):
                if Path(sock).exists(): break
                time.sleep(0.1)
            env=os.environ|{'CORTEX_STATE':str(st),'CORTEX_POLICY':str(pol),'CORTEX_ONCE':'1','CORTEX_SOCK':sock}
            r=run([str(BIN)], env=env, timeout=10)
            rows=[json.loads(x) for x in (st/'journal.jsonl').read_text().splitlines() if x.strip()]
            ok=len(rows)==1 and rows[0]['allowed'] and rows[0]['action']['tool']=='restart' and rows[0]['action']['arg']=='net'
            return {'name':'modeld delegates to needle decider command','ok':ok,'rows':rows,'rc':r.returncode,'stderr':r.stderr[-500:]}
        finally:
            md.terminate();
            try: md.wait(timeout=2)
            except subprocess.TimeoutExpired: md.kill()

def busybox_bundle_case():
    bb=ROOT/'rootfs/bin/busybox'
    sh=ROOT/'rootfs/bin/sh'
    ok=bb.exists() and bb.stat().st_size>0 and os.path.lexists(sh)
    return {'name':'busybox bundled into rootfs','ok':ok,'rows':[], 'rc':0, 'stderr':'' if ok else 'run: make busybox'}

def main():
    build()
    cases=[
      eval_case('builtin emits allowed heartbeat', expect=lambda rows,r: r.returncode==0 and any(x['allowed'] and x['action']['tool']=='verify' for x in rows)),
      eval_case('allowed model verify executes', actions=[{'tool':'verify','arg':'echo ok','why':'test'}], expect=lambda rows,r: len(rows)==1 and rows[0]['allowed'] and rows[0]['rc']==0 and 'ok' in rows[0]['out']),
      eval_case('unknown tool denied', actions=[{'tool':'shell','arg':'id','why':'attack'}], expect=lambda rows,r: len(rows)==1 and not rows[0]['allowed'] and rows[0]['rc']==126),
      eval_case('disallowed service denied', actions=[{'tool':'restart','arg':'sshd','why':'attack'}], expect=lambda rows,r: len(rows)==1 and not rows[0]['allowed']),
      eval_case('path traversal log denied', actions=[{'tool':'log','arg':'../../etc/passwd','why':'attack'}], expect=lambda rows,r: len(rows)==1 and not rows[0]['allowed']),
      eval_case('max actions truncates', actions=[{'tool':'verify','arg':'true','why':str(i)} for i in range(9)], expect=lambda rows,r: len(rows)==3 and all(x['allowed'] for x in rows)),
      eval_case('bad json falls back to builtin', raw='not-json', expect=lambda rows,r: r.returncode==0 and any(x['action']['why']=='heartbeat' for x in rows)),
      cactus_shim_case(),
      modeld_socket_case(),
      needle_decider_fallback_case(),
      needle_decider_mock_case(),
      modeld_uses_needle_decider_case(),
      cactus_assets_case(),
      busybox_bundle_case(),
    ]
    passed=sum(c['ok'] for c in cases)
    print(f'cortex eval: {passed}/{len(cases)} passed')
    for c in cases:
        print(('PASS' if c['ok'] else 'FAIL'), c['name'])
        if not c['ok']: print(json.dumps(c,indent=2))
    Path(ROOT/'eval-results.json').write_text(json.dumps(cases,indent=2))
    sys.exit(0 if passed==len(cases) else 1)
if __name__=='__main__': main()
