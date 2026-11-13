#!/usr/bin/env bash
# Summarize child runs in the E2E env (newest last).  e2e/inspect.sh [N]
ROOT="${E2E_ROOT:-/tmp/ppaa-e2e}"
python3 -I - "$ROOT" "${1:-10}" <<'PY'
import json, glob, os, sys
root, n = sys.argv[1], int(sys.argv[2])
metas = sorted(glob.glob(f"{root}/agent/sessions/*/subagent-artifacts/*_meta.json"), key=os.path.getmtime)[-n:]
for m in metas:
    d = json.load(open(m)); u = d.get("usage", {})
    print(f"{d['runId'][:8]} agent={d.get('agent')} req={d.get('requestedModel')} model={d.get('model')} "
          f"exit={d.get('exitCode')} accept={d.get('acceptance',{}).get('status')} cost=${u.get('cost',0):.4f} turns={u.get('turns')}")
PY
