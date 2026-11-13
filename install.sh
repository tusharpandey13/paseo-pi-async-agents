#!/usr/bin/env bash
# Install async-agents into a pi agent directory. Idempotent. Dry run by default.
#   ./install.sh                     show planned links and settings diff
#   ./install.sh --apply             write them (settings.json backed up first)
#   --agent-dir DIR                  target (default: $PI_CODING_AGENT_DIR or ~/.pi/agent)
#   --dev                            also merge dev/models.mock.json (Bedrock ids -> deepseek-flash)
#                                    refused for the default agent dir
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AD="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
APPLY=0 DEV=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --dev) DEV=1 ;;
    --agent-dir) AD="$2"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
AD="${AD%/}"
if [ "$DEV" = 1 ] && [ "$(cd "$AD" 2>/dev/null && pwd -P)" = "$(cd "$HOME/.pi/agent" 2>/dev/null && pwd -P)" ]; then
  echo "refusing --dev for the default agent dir; pass --agent-dir to an isolated dir" >&2; exit 2
fi

say() { if [ "$APPLY" = 1 ]; then echo "$@"; else echo "[dry-run] $@"; fi; }

link() { # src dst
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then echo "ok      $dst"; return; fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then echo "SKIP    $dst exists and is not a symlink" >&2; return; fi
  say "link    $dst -> $src"
  if [ "$APPLY" = 1 ]; then mkdir -p "$(dirname "$dst")"; ln -sfn "$src" "$dst"; fi
}

link "$REPO/skills/async-agents" "$AD/skills/async-agents"
for f in "$REPO"/prompts/*.md; do link "$f" "$AD/prompts/$(basename "$f")"; done
for f in "$REPO"/agents/*.md; do link "$f" "$AD/agents/$(basename "$f")"; done

# AGENTS.md pointer (appended once, marker-guarded)
MARK='<!-- paseo-pi-async-agents -->'
if grep -qF "$MARK" "$AD/AGENTS.md" 2>/dev/null; then echo "ok      $AD/AGENTS.md pointer"
else
  say "append  $AD/AGENTS.md pointer"
  if [ "$APPLY" = 1 ]; then mkdir -p "$AD"; { [ -s "$AD/AGENTS.md" ] && echo; cat "$REPO/agents-md.fragment.md"; } >> "$AD/AGENTS.md"; fi
fi

# JSON merges: settings.json <- settings.fragment.json ; (dev) models.json <- dev/models.mock.json
python3 -I - "$APPLY" "$AD" "$REPO" "$DEV" <<'PY'
import json, sys, os, time, difflib
apply, ad, repo, dev = sys.argv[1] == "1", sys.argv[2], sys.argv[3], sys.argv[4] == "1"

def merge(base, frag):
    """Deep-merge dicts; frag wins on leaves; lists are replaced."""
    out = dict(base)
    for k, v in frag.items():
        out[k] = merge(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out

def merge_models(base, frag):
    """Merge provider blocks; models lists merge by id."""
    out = json.loads(json.dumps(base))
    provs = out.setdefault("providers", {})
    for name, p in frag.get("providers", {}).items():
        cur = provs.setdefault(name, {})
        models = {m["id"]: m for m in cur.get("models", [])}
        models.update({m["id"]: m for m in p.get("models", [])})
        cur.update({k: v for k, v in p.items() if k != "models"})
        cur["models"] = list(models.values())
    return out

def do(path, frag_path, fn):
    try:
        with open(path) as f: base = json.load(f)
    except FileNotFoundError: base = {}
    with open(frag_path) as f: frag = json.load(f)
    new = fn(base, frag)
    a, b = json.dumps(base, indent=2).splitlines(), json.dumps(new, indent=2).splitlines()
    if a == b: print(f"ok      {path}"); return
    print(("merge   " if apply else "[dry-run] merge   ") + path)
    sys.stdout.writelines(l + "\n" for l in difflib.unified_diff(a, b, "before", "after", lineterm="", n=1))
    if apply:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.exists(path):
            os.replace(path, f"{path}.bak.{time.strftime('%Y%m%d%H%M%S')}")
        with open(path, "w") as f: json.dump(new, f, indent=2); f.write("\n")

do(os.path.join(ad, "settings.json"), os.path.join(repo, "settings.fragment.json"), merge)
if dev:
    do(os.path.join(ad, "models.json"), os.path.join(repo, "dev", "models.mock.json"), merge_models)
PY
