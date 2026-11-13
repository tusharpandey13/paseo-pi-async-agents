#!/usr/bin/env bash
# Run E2E cases concurrently.  e2e/cases.sh E2 E4 ...   (no args: all listed below)
cd "$(dirname "$0")"
ROOT="${E2E_ROOT:-/tmp/ppaa-e2e}"; mkdir -p "$ROOT/logs" "$ROOT/work"
declare -A P=(
 [E2]="using haiku, do this in a subagent: reply with exactly 'haiku ok'"
 [E3]="delegate: haiku scouts /tmp/ppaa-e2e/work/notes.txt and reports its line count, opus reviews that the count is plausible. Two children."
 [E4]="parallelize these 3 tiny tasks: (a) reply 'alpha' (b) reply 'beta' (c) reply 'gamma'"
 [E5]="do this in a subagent: list the exact names of every tool you have, one per line, then call estimate_cost once. Also run a second subagent with the builtin 'delegate' agent doing the same, as a control."
 [E9]="do this in a subagent: without reading any files, answer from your own instructions only: what must be true of git commits?"
 [E10]="what's the difference between sonnet and haiku?"
 [E11]="use haiku and opus to summarize /tmp/ppaa-e2e/work/notes.txt"
 [E12]="do this in a sonet subagent: reply 'sonet ok'"
 [E18]="/haiku reply with exactly 'slash ok'"
 [E8a]="using haiku, do this in a subagent: reply with exactly 'p1'"
 [E8b]="using haiku, do this in a subagent: reply with exactly 'p2'"
 [E8c]="using haiku, do this in a subagent: reply with exactly 'p3'"
 [E13]="do this in a subagent using model amazon-bedrock/global.anthropic.claude-sonnet-9-9: reply 'x'"
 [E14]="do this in a subagent: run 'sleep 90' with bash, then reply 'done'. After it launches, steer it to reply 'steered' instead, check its status, then stop it, and report each state you observed."
 [E15]="delegate to a subagent: in the git repo /tmp/ppaa-e2e/work/repo append a line 'hello' to README.md. Use an isolated worktree. Do not commit."
 [E16]="do this in a subagent: the child must try to call the subagent tool to launch its own child, and report whether that tool exists and what happened."
 [E20b]="do this in a subagent with the builtin scout agent, async (background): count the lines of /tmp/ppaa-e2e/work/notes.txt and call estimate_cost first. Report the child's tool list."
 [E20]="do this in a subagent with the builtin scout agent in the foreground (async false): count the lines of /tmp/ppaa-e2e/work/notes.txt and call estimate_cost first."
)
ids=("$@"); [ ${#ids[@]} -eq 0 ] && ids=(E2 E3 E4 E5 E9 E10 E11 E12 E18)
printf 'line one\nline two\nline three\n' > "$ROOT/work/notes.txt"
for id in "${ids[@]}"; do E2E_TAIL=12 ./run.sh "$id" "${P[$id]}" > "$ROOT/logs/$id.summary" 2>&1 & done
wait; for id in "${ids[@]}"; do echo "===== $id"; cat "$ROOT/logs/$id.summary"; done
