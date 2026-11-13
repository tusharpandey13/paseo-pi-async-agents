#!/usr/bin/env bash
# Run E2E cases concurrently.  e2e/cases.sh E2 E4 ...   (no args: all listed below)
cd "$(dirname "$0")"
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
)
ids=("$@"); [ ${#ids[@]} -eq 0 ] && ids=(E2 E3 E4 E5 E9 E10 E11 E12 E18)
printf 'line one\nline two\nline three\n' > /tmp/ppaa-e2e/work/notes.txt
for id in "${ids[@]}"; do E2E_TAIL=12 ./run.sh "$id" "${P[$id]}" > "/tmp/ppaa-e2e/logs/$id.summary" 2>&1 & done
wait; for id in "${ids[@]}"; do echo "===== $id"; cat "/tmp/ppaa-e2e/logs/$id.summary"; done
