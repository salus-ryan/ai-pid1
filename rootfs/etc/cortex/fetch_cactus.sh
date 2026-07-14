#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TP="$ROOT/third_party"
HF="$TP/needle-hf"
mkdir -p "$TP" "$HF"
say(){ printf '%s\n' "[cactus] $*"; }
clone_or_pull(){ url="$1"; dir="$2"; if [ -d "$dir/.git" ]; then say "update $dir"; git -C "$dir" pull --ff-only || true; else say "clone $url"; git clone --depth 1 "$url" "$dir"; fi; }
clone_or_pull https://github.com/cactus-compute/cactus.git "$TP/cactus"
clone_or_pull https://github.com/cactus-compute/needle.git "$TP/needle"
py(){ command -v python3 >/dev/null 2>&1 && python3 "$@" || python "$@"; }
py - <<'PY' "$HF" "${AI_PID1_CACTUS_FULL:-0}"
import sys,urllib.request,os,json
out,full=sys.argv[1],sys.argv[2] not in ('0','false','False','no','')
os.makedirs(out,exist_ok=True)
base='https://huggingface.co/Cactus-Compute/needle/resolve/main/'
files=['README.md','config.json','special_tokens_map.json','tokenizer.model']
if full: files+=['model.safetensors','needle.pkl']
for f in files:
 p=os.path.join(out,f)
 if os.path.exists(p) and os.path.getsize(p)>0: continue
 print('[cactus] download',f)
 urllib.request.urlretrieve(base+f,p)
open(os.path.join(out,'MANIFEST.json'),'w').write(json.dumps({'repo':'Cactus-Compute/needle','full':full,'files':files},indent=2))
PY
say "OK: $TP"
