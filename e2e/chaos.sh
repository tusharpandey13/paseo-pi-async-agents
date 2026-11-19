#!/usr/bin/env bash
# Chaos e2e suite (issue #4): parallel and failing children, checked through e2e/paseo-subagents.mjs.
#   e2e/chaos.sh [1 2 3 4 5 6]      (no args: all six cases; exit 1 if any case FAILs; SKIP does not fail)
# Everything lives in one temp dir (E2E_ROOT, default a fresh mktemp dir) that is removed on exit
# (E2E_KEEP=1 keeps it). It starts its OWN Paseo daemon (own PASEO_HOME and port, never ~/.paseo) whose
# pi provider reads the isolated pi agent dir built by e2e/setup.sh (Bedrock ids mocked to deepseek-flash).
# Parents run on deepseek/deepseek-flash. Env: PASEO_APP (default /Applications/Paseo.app),
# PASEO_ASAR_DIR (a pre-extracted app.asar), CHAOS_BUDGET_USD (default 1.50), CHAOS_TIMEOUT (per wait, default 300).
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$REPO/e2e/paseo-subagents.mjs"
KEEP_ASAR="${PASEO_ASAR_DIR:-}" KEEP_APP="${PASEO_APP:-}"
for k in $(env | grep -o '^\(PASEO\|AWT\|PI\)[A-Z_]*'); do unset "$k"; done   # never inherit a live Paseo/awt/pi context
unset AWT_MODEL
ROOT="${E2E_ROOT:-$(mktemp -d /tmp/ppaa-chaos-run.XXXXXX)}"; export E2E_ROOT="$ROOT"
AD="$ROOT/agent" HOME_P="$ROOT/paseo" LOGS="$ROOT/logs" PROJ="$ROOT/work/repo" OUT="$ROOT/awt-node/agents"
BUDGET="${CHAOS_BUDGET_USD:-1.50}"; TMO="${CHAOS_TIMEOUT:-300}"
PROVIDER="pi/deepseek/deepseek-flash"
ids=("$@"); [ ${#ids[@]} -eq 0 ] && ids=(1 2 3 4 5 6)
mkdir -p "$ROOT" "$LOGS"
export PI_CODING_AGENT_DIR="$AD" AWT_DIR="$ROOT/awt-node" AWT_BY=e2e-parent PASEO_HOME="$HOME_P"

cleanup() {
  paseo --home "$HOME_P" daemon stop >/dev/null 2>&1
  if [ "${E2E_KEEP:-}" = 1 ]; then echo "kept $ROOT"; else rm -rf "$ROOT"; fi
}
trap 'cleanup' EXIT
trap 'exit 130' INT TERM

spend() { python3 -I - "$AD/governor-history.jsonl" <<'PY'
import json, sys
t = 0.0
try:
    for l in open(sys.argv[1]): t += json.loads(l).get("usd", 0)
except OSError: pass
print(f"{t:.4f}")
PY
}
over_budget() { python3 -I -c "import sys; sys.exit(0 if float('$(spend)') >= float('$BUDGET') else 1)"; }

# ---- environment ------------------------------------------------------------------------------------
echo "chaos suite: root $ROOT"
"$REPO/e2e/setup.sh" > "$LOGS/setup.log" 2>&1 || { echo "setup failed, see $LOGS/setup.log"; tail -5 "$LOGS/setup.log"; exit 3; }
ASAR="${KEEP_ASAR:-$ROOT/asar}"
if [ ! -f "$ASAR/node_modules/@getpaseo/cli/dist/utils/client.js" ]; then
  npx -y @electron/asar extract "${KEEP_APP:-/Applications/Paseo.app}/Contents/Resources/app.asar" "$ASAR" > "$LOGS/asar.log" 2>&1
  [ -f "$ASAR/node_modules/@getpaseo/cli/dist/utils/client.js" ] || { echo "cannot extract Paseo client (see $LOGS/asar.log)"; exit 3; }
fi
PORT=$(python3 -I -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1])")
mkdir -p "$HOME_P"
cat > "$HOME_P/config.json" <<EOF
{"version":1,"pluginsEnabled":false,"daemon":{"listen":"127.0.0.1:$PORT","relay":{"enabled":false},"mcp":{"injectIntoAgents":false}},"features":{"dictation":{"enabled":false}}}
EOF
paseo --home "$HOME_P" daemon start --timeout 90 > "$LOGS/daemon-start.log" 2>&1 || { echo "isolated daemon did not start"; tail -5 "$LOGS/daemon-start.log"; exit 3; }
paseo --home "$HOME_P" project create "$PROJ" >/dev/null 2>&1
PV=$(paseo --version 2>/dev/null)
echo "isolated Paseo $PV on 127.0.0.1:$PORT, home $HOME_P, provider $PROVIDER"

# ---- helpers ----------------------------------------------------------------------------------------
P() { paseo --home "$HOME_P" "$@"; }
launch() {   # launch <title> <prompt> -> agent id (exits the case when the daemon refuses)
  P run --provider "$PROVIDER" --cwd "$PROJ" --title "$1" --no-wait --json "$2" 2>"$LOGS/launch-$1.err" | grep -o '"agentId": *"[^"]*"' | cut -d'"' -f4
}
rows() {     # rows <agent id> <paseo-subagents.mjs args...>
  local id="$1"; shift
  PASEO_ASAR_DIR="$ASAR" PASEO_HOST="127.0.0.1:$PORT" node "$CHECK" "$id" "$@"
}
parent_text() {  # parent_text <agent id>: assistant messages only
  P logs --json "$1" 2>/dev/null | python3 -I -c "
import json,sys
for i in json.load(sys.stdin).get('items',[]):
    if i.get('type')=='assistant_message': print(i.get('text',''))"
}
FAILS=0
# say <expected> <observed> <label>: print one expected-vs-observed line, count a mismatch
say() { if [ "$1" = "$2" ]; then echo "  ok   $3: expected $1, observed $2"; else echo "  FAIL $3: expected $1, observed $2"; FAILS=$((FAILS+1)); fi; }
note() { echo "  note $*"; }
rowcheck() { # rowcheck <id> <label> <args...>: run the row checker, show its output, count a failure
  local id="$1" label="$2"; shift 2
  local o; o=$(rows "$id" "$@" 2>&1); local rc=$?
  echo "$o" | sed 's/^/    /'
  [ $rc -eq 0 ] && echo "  ok   $label: rows match ($*)" || { echo "  FAIL $label: paseo-subagents.mjs exit $rc ($*)"; FAILS=$((FAILS+1)); }
  return 0
}

NATO=(alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima)

# ---- cases ------------------------------------------------------------------------------------------
case1() {  # 12 children in one reply: 12 rows in launch order
  local order; order=$(IFS=,; echo "${NATO[*]}")
  local id; id=$(launch c1 "Delegate 12 independent tiny tasks, one async subagent each (agent general-ro), all 12 launched as 12 single subagent calls in one reply. Seams in this exact order: ${order//,/, }. The child for seam X replies with exactly 'X ok'. The first line of each brief is 'Say X ok' (X is the seam word). Use RUN_KEY X-<n> per the skill.")
  echo "case 1  12 children in one reply (parent $id)"
  echo "  expected: 12 rows, all completed, in launch order $order"
  rows "$id" --settle "$TMO" --expect 12 --order "$order" --expect-counts completed=12 >/dev/null 2>&1   # wait for children
  rowcheck "$id" rows --expect 12 --order "$order" --expect-counts completed=12
}

case2() {  # one launch fails mid-batch
  local id; id=$(launch c2 "Do these 5 tasks as 5 separate parallel async subagents (agent general-ro), launched in the same reply, in this order. Seams: red, green, bad, blue, amber. Each child replies exactly '<seam> ok'. Each brief's first line is 'Say <seam> ok'. For the child 'bad', pass the model exactly as amazon-bedrock/global.anthropic.claude-sonnet-9-9 even if you think it is invalid; do not substitute it and do not retry it. After launching, report which launches failed.")
  echo "case 2  one launch fails mid-batch (parent $id)"
  echo "  expected: 5 rows in order red,green,bad,blue,amber; 4 completed + 1 failed (the bad one)"
  rows "$id" --settle "$TMO" --expect 5 --expect-counts completed=4,failed=1 >/dev/null 2>&1
  rowcheck "$id" rows --expect 5 --order red,green,bad,blue,amber --expect-counts completed=4,failed=1
  local st; st=$(rows "$id" --json 2>/dev/null | python3 -I -c "
import json,sys
print(','.join(f\"{r['first'].split()[1] if len(r['first'].split())>1 else '?'}={r['status']}\" for r in json.load(sys.stdin)['rows']))")
  say "bad=failed" "$(echo "$st" | tr ',' '\n' | grep '^bad=')" "status of the bad row"
}

case3() {  # stop and resume
  local id; id=$(launch c3 "Do this in a subagent (async, agent general-ro, seam nap): run 'sleep 60' with bash, then reply 'done'. First line of the brief: 'Sleep then say done'. After it launches: sleep 10 in bash, call subagent action stop on that child, sleep 10 in bash, then try subagent action resume on that same stopped run (original run id) with the message 'just reply done now' and quote the exact error if it fails. Then launch a NEW async general-ro child (seam wake, first line 'Say done now') that replies exactly 'done'. Report what you saw.")
  echo "case 3  stop and resume (parent $id)"
  echo "  expected: row statuses running, canceled, running, completed"
  echo "            (one row cannot do all four: pi-subagents ends a stopped run for good and a new run is a new row,"
  echo "             so the check is row 1 = running,canceled and row 2 = running,completed)"
  rowcheck "$id" sequence --watch "$TMO" --expect 2 --expect-seq "running,canceled|running,completed"
  P wait "$id" --timeout 120 >/dev/null 2>&1
  local t; t=$(parent_text "$id")
  if echo "$t" | grep -qi 'cannot be resumed\|not resumable\|was stopped'; then note "resume of the stopped run was refused: $(echo "$t" | grep -i -m1 'cannot be resumed\|not resumable\|was stopped' | cut -c1-160)"
  else note "the parent's report did not mention the resume refusal"; fi
}

case4() {  # a child past the 200-item / 2 MB timeline caps
  local cmd="head -c 12000 /dev/zero | tr '\\0' x" attempt id big bytes=0 calls=0
  echo "case 4  child over the 200-item / 2 MB timeline caps"
  echo "  expected: 1 row completed; child session over 2 MB; row timeline capped (at most 200 items); result file complete ('BULK DONE 230')"
  for attempt in 1 2; do   # the child is a mocked cheap model: retry once when it stops short of the volume
    rm -rf "$OUT"/bulk-*
    id=$(launch "c4-$attempt" "Do this in a subagent (async, agent general-ro, seam bulk). First line of the brief: 'Emit bulk tool output'. The child must make 230 separate bash tool calls (many per turn, in parallel), each running exactly: $cmd ; it must not stop early, must not call contact_supervisor and must not summarise or skip calls. Then it appends the line 'BULK DONE 230' to its output file with a last bash call and replies 'bulk done'. The output file must exist at the end.")
    echo "  attempt $attempt (parent $id)"
    rows "$id" --settle "$TMO" --expect 1 >/dev/null 2>&1
    big=$(ls -S "$AD"/sessions/*/*/*/run-0/session.jsonl 2>/dev/null | head -1)
    bytes=0; calls=0
    [ -n "$big" ] && { bytes=$(wc -c < "$big" | tr -d ' '); calls=$(grep -o '"type":"toolCall"' "$big" | wc -l | tr -d ' '); }
    [ "$bytes" -gt 2097152 ] && break
    echo "  attempt $attempt: child session only $bytes bytes, $calls tool calls; volume not reached"
  done
  rowcheck "$id" rows --expect 1 --expect-counts completed=1 --timeline
  say "over 2097152" "$([ "$bytes" -gt 2097152 ] && echo "over 2097152" || echo "$bytes bytes ($calls tool calls)")" "child session size (cap precondition)"
  local items; items=$(rows "$id" --json --timeline 2>/dev/null | python3 -I -c "
import json,sys
r=json.load(sys.stdin)['rows']; print(r[0]['timelineItems'] if r else 'no row')")
  say "1..200" "$([ "$items" -ge 1 ] 2>/dev/null && [ "$items" -le 200 ] && echo 1..200 || echo "$items")" "row timeline items (session has $calls tool calls, $bytes bytes)"
  local f; f=$(ls "$OUT"/bulk-*/out.md 2>/dev/null | head -1)
  say "present" "$([ -n "$f" ] && grep -q 'BULK DONE 230' "$f" && echo present || echo "missing or incomplete (${f:-no file})")" "result file ends with BULK DONE 230"
}

case5() {  # workflow launch: no rows, skill warns
  local id; id=$(launch c5 "Run these 3 independent jobs as a workflow script (workflow:true, runs.all): count the lines of three files a.txt, b.txt and c.txt in the current directory.")
  echo "case 5  workflow launch, negative case (parent $id)"
  echo "  expected: 0 rows; the parent warns that Paseo will not list the workflow's children"
  P wait "$id" --timeout "$TMO" >/dev/null 2>&1
  rowcheck "$id" rows --expect 0
  local t w; t=$(parent_text "$id")
  w=$(echo "$t" | grep -ciE 'paseo.{0,100}(list|show|track|visible|pill|row|open)|(invisible|unopenable|not (be )?(listed|tracked|shown))')
  say "warning" "$([ "$w" -gt 0 ] && echo warning || echo "no warning; reply began: $(echo "$t" | tr '\n' ' ' | cut -c1-240)")" "skill warning in the parent's reply"
}

case6() {  # two parents at once: distinct RUN_KEYs, no overwritten output
  local a b ta tb
  ta="zeta$RANDOM"; tb="eta$RANDOM"
  a=$(launch c6a "Do this in a subagent (async, agent general-ro, seam dup): reply with exactly '$ta'. First line of the brief: 'Say $ta'.")
  b=$(launch c6b "Do this in a subagent (async, agent general-ro, seam dup): reply with exactly '$tb'. First line of the brief: 'Say $tb'.")
  echo "case 6  two parents launching at once (parents $a, $b)"
  echo "  expected: 2 distinct RUN_KEYs, each out.md holds its own child's reply ($ta, $tb)"
  rows "$a" --settle "$TMO" --expect 1 >/dev/null 2>&1; rows "$b" --settle "$TMO" --expect 1 >/dev/null 2>&1
  rowcheck "$a" "parent A rows" --expect 1 --expect-counts completed=1
  rowcheck "$b" "parent B rows" --expect 1 --expect-counts completed=1
  local ka kb jq='import json,sys;print(json.load(sys.stdin)["rows"][0].get("runKey","none"))'
  ka=$(rows "$a" --json 2>/dev/null | python3 -I -c "$jq"); kb=$(rows "$b" --json 2>/dev/null | python3 -I -c "$jq")
  say "distinct" "$([ "$ka" != "$kb" ] && [ "$ka" != none ] && echo distinct || echo "A=$ka B=$kb")" "RUN_KEYs (A=$ka, B=$kb)"
  local fa fb
  fa="$OUT/$ka/out.md"; fb="$OUT/$kb/out.md"
  say "present" "$(grep -q "$ta" "$fa" 2>/dev/null && echo present || echo "A's reply missing in $fa")" "parent A output file holds $ta"
  say "present" "$(grep -q "$tb" "$fb" 2>/dev/null && echo present || echo "B's reply missing in $fb")" "parent B output file holds $tb"
}

# ---- run --------------------------------------------------------------------------------------------
declare -A RES
for n in "${ids[@]}"; do
  if over_budget; then echo "budget \$$BUDGET reached (spent \$$(spend)); skipping case $n"; RES[$n]=SKIP; continue; fi
  ( FAILS=0; "case$n" > "$LOGS/case$n.out" 2>&1; echo "$FAILS" > "$LOGS/case$n.fails" ) &
done
wait
rc=0
for n in "${ids[@]}"; do
  [ "${RES[$n]:-}" = SKIP ] && continue
  cat "$LOGS/case$n.out"
  f=$(cat "$LOGS/case$n.fails" 2>/dev/null || echo 1)
  if [ "$f" = 0 ]; then echo "  => case $n PASS"; else echo "  => case $n FAIL ($f check(s))"; rc=1; fi
  echo
done
echo "spend: \$$(spend) of \$$BUDGET (governor-history in the isolated agent dir)"
[ $rc -eq 0 ] && echo "chaos suite: PASS" || echo "chaos suite: FAIL"
exit $rc
