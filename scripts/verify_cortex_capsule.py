#!/usr/bin/env python3
import json,sys,hashlib
from pathlib import Path
p=Path(sys.argv[1] if len(sys.argv)>1 else 'CORTEX_CAPSULE.json')
d=json.loads(p.read_text())
need=['schema','boot_graph','action_schema','safety_invariants','hashes','capsule_sha256']
missing=[x for x in need if x not in d]
assert not missing, missing
assert d['schema']=='cortex.boot-capsule.v1'
assert 'model is never PID1' in d['safety_invariants']
assert 'policy validates before execution' in d['safety_invariants']
c=d.pop('capsule_sha256')
calc=hashlib.sha256(json.dumps(d,sort_keys=True,separators=(',',':')).encode()).hexdigest()
assert c==calc, 'capsule hash mismatch'
print('capsule ok',c)
