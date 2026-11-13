#!/usr/bin/env bash
# Run one parent turn headless in the isolated E2E env.  e2e/run.sh <ID> "<prompt>"
# Parent model: mocked Sonnet id. Log: $E2E_ROOT/logs/<ID>.log ; prints the tail.
set -uo pipefail
ROOT="${E2E_ROOT:-/tmp/ppaa-e2e}"; ID="$1"; shift
mkdir -p "$ROOT/logs" "$ROOT/work"
cd "$ROOT/work"
AWT=(AWT_DIR="$ROOT/awt-node" AWT_BY="e2e-parent"); [ "${E2E_NO_AWT:-}" = 1 ] && AWT=()
env -u AWT_DIR -u AWT_BY PI_CODING_AGENT_DIR="$ROOT/agent" "${AWT[@]}" \
  timeout "${E2E_TIMEOUT:-600}" pi -p --model "${E2E_MODEL:-amazon-bedrock/global.anthropic.claude-sonnet-5-5}" "$@" \
  > "$ROOT/logs/$ID.log" 2>&1
echo "exit=$? log=$ROOT/logs/$ID.log"; tail -n "${E2E_TAIL:-15}" "$ROOT/logs/$ID.log"
