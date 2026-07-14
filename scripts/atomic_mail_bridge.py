#!/usr/bin/env python3
"""Atomic Mail polling bridge.
Atomic Mail webhooks/WebSockets are roadmap, not live yet. This provides the
same practical behavior by polling JMAP and POSTing new messages to a webhook.

Env:
  ATOMIC_MAIL_CREDENTIALS_DIR  default: ./.atomicmail, ~/ai-pid1/.atomicmail, ~/.atomicmail
  ATOMIC_MAIL_WEBHOOK_URL      if set, POST each new message as JSON
  ATOMIC_MAIL_POLL_SECONDS     default: 60
  ATOMIC_MAIL_COUNT            default: 20
  ATOMIC_MAIL_SEEN_FILE        default: <credentials-dir>/seen.json
"""
import json, os, subprocess, sys, time, urllib.request, signal
from pathlib import Path
try: signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception: pass

def cred_dir():
    for d in [os.getenv('ATOMIC_MAIL_CREDENTIALS_DIR'), './.atomicmail', str(Path.home()/'ai-pid1/.atomicmail'), str(Path.home()/'.atomicmail')]:
        if d and (Path(d)/'credentials.json').exists(): return Path(d).resolve()
    raise SystemExit('No Atomic Mail credentials found')

def jmap(cdir, count):
    ops={"using":["urn:ietf:params:jmap:core","urn:ietf:params:jmap:mail"],"methodCalls":[["Email/query",{"accountId":"$ACCOUNT_ID","filter":{"inMailbox":"$INBOX_MAILBOX_ID"},"sort":[{"property":"receivedAt","isAscending":False}],"limit":count},"q0"],["Email/get",{"accountId":"$ACCOUNT_ID","#ids":{"resultOf":"q0","name":"Email/query","path":"/ids"},"properties":["id","subject","from","to","receivedAt","preview","textBody","bodyValues","messageId"],"fetchTextBodyValues":True},"g0"]]}
    p=subprocess.run(['npx','--yes','--package=@atomicmail/agent-skill','atomicmail','jmap_request','--credentials-dir',str(cdir),'--ops',json.dumps(ops)],text=True,capture_output=True,timeout=120)
    if p.returncode: raise RuntimeError(p.stderr or p.stdout)
    data=json.loads(p.stdout)
    return data['methodResponses'][1][1].get('list',[])

def body(msg):
    vals=msg.get('bodyValues') or {}
    for v in vals.values():
        if isinstance(v,dict) and v.get('value'): return v['value']
    return msg.get('preview','')

def post(url, payload):
    req=urllib.request.Request(url,json.dumps(payload).encode(),{'Content-Type':'application/json','User-Agent':'ai-pid1-atomic-mail-bridge/1'})
    with urllib.request.urlopen(req,timeout=20) as r: return r.status

def load_seen(path):
    try: return set(json.loads(path.read_text()))
    except Exception: return set()

def save_seen(path, seen): path.write_text(json.dumps(sorted(seen)))

def once(cdir, seen_path, webhook, count):
    seen=load_seen(seen_path); msgs=jmap(cdir,count); new=[]
    for m in reversed(msgs):
        mid=m['id']
        if mid in seen: continue
        seen.add(mid)
        payload={'id':mid,'subject':m.get('subject'), 'from':m.get('from'), 'to':m.get('to'), 'receivedAt':m.get('receivedAt'), 'preview':m.get('preview'), 'body':body(m), 'messageId':m.get('messageId')}
        if webhook: post(webhook,payload)
        else: print(json.dumps(payload,indent=2), flush=True)
        new.append(mid)
    save_seen(seen_path,seen)
    return len(new)

def main():
    cdir=cred_dir(); count=int(os.getenv('ATOMIC_MAIL_COUNT','20')); webhook=os.getenv('ATOMIC_MAIL_WEBHOOK_URL')
    seen_path=Path(os.getenv('ATOMIC_MAIL_SEEN_FILE', str(cdir/'seen.json')))
    interval=int(os.getenv('ATOMIC_MAIL_POLL_SECONDS','60'))
    if '--once' in sys.argv: raise SystemExit(0 if once(cdir,seen_path,webhook,count)>=0 else 1)
    while True:
        try: n=once(cdir,seen_path,webhook,count); print(f'[atomic-mail-bridge] new={n}', flush=True)
        except Exception as e: print(f'[atomic-mail-bridge] error: {e}', file=sys.stderr, flush=True)
        time.sleep(interval)
if __name__=='__main__': main()
