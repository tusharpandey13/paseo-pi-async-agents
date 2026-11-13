#!/usr/bin/env bash
# Build an isolated pi agent dir for E2E. Never touches ~/.pi/agent except reading auth.
#   E2E_ROOT (default /tmp/ppaa-e2e)  PCG (default ~/src/wt/pi-governor)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${E2E_ROOT:-/tmp/ppaa-e2e}" AD="$ROOT/agent" NODE="$ROOT/awt-node"
PCG="${PCG:-$HOME/src/wt/pi-governor}"
mkdir -p "$AD" "$NODE" "$ROOT/work"
cp ~/.pi/agent/auth.json "$AD/"
[ -f ~/.pi/agent/models-store.json ] && cp ~/.pi/agent/models-store.json "$AD/"
[ -f "$AD/settings.json" ] || echo '{"defaultProvider":"deepseek","defaultModel":"deepseek-flash","packages":[]}' > "$AD/settings.json"
cp "$REPO/e2e/fixtures/AGENTS.md" "$AD/AGENTS.md"
export PI_CODING_AGENT_DIR="$AD"
grep -q 'pi-subagents' "$AD/settings.json" || pi install npm:pi-subagents@0.88.1 >/dev/null
grep -q 'pi-governor' "$AD/settings.json" || pi install "$PCG" >/dev/null
[ -d "$NODE/.awt" ] || awt --dir "$NODE" init --goal "ppaa e2e scratch" --done "e2e ledger complete" >/dev/null
"$REPO/install.sh" --agent-dir "$AD" --dev --apply >/dev/null
echo "agent dir: $AD"; echo "awt node:  $NODE"
