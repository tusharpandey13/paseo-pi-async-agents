# Spec: delegate (issues on repos owned by tusharpandey13)

Goal: record the follow-up work that belongs in our own repos as draft issues, and own the chaos e2e that was moved out of FLASH.md. Context: `/Users/tushar.pandey/src/paseo-pi-async-agents/docs/PASEO-PARITY.md` and `/Users/tushar.pandey/src/paseo-pi-async-agents/docs/SPEC.md`.

The delegated agent only **drafts** issue files. It does not create issues. The parent queues them with `awt effect plan` for a person to approve.

## Repos and issues
All three repos are `tusharpandey13/<name>`: `paseo-pi-async-agents`, `awt`, `pcg`. Audience: public (tag every point `{pub}`, nothing internal).

paseo-pi-async-agents:
1. Guard: when the user or a brief asks for a workflow script, the skill warns that Paseo will not list its children, and offers single calls instead.
2. E19 parity check: run `e2e/paseo-subagents.mjs` in the regression runbook after each pi-subagents or Paseo upgrade.
3. Chaos e2e suite (moved from FLASH): 12 parallel children (Paseo row count and ordering), a failed launch mid-batch, stop and resume row transitions, a child past the 200-item/2 MB timeline cap, a workflow launch as a negative case, two parent sessions launching at once (RUN_KEY collisions).
4. Measure how the Paseo row truncates a long first line, then tune the title length limit.

awt:
5. Give each child its own sub-node instead of a shared `AWT_DIR` and `AWT_BY` (known risk #4 in SPEC section 10).
6. Record the link from a Paseo subagent row (`toolCallId`) to the child's `RUN_KEY`, so notes point at the row.

pcg:
7. Optional: write a per-child cost line next to each child's output file, so a parent summary can quote it without extra calls. State plainly that nothing blocks on this.

## Issue format
Each issue file: `# <title>` (at most 70 characters), then `Problem`, `Evidence` (file paths in the public repos, command output), `Proposed change`, `Acceptance`. Facts only: no promises, no asks, no narration. Run each through the pipeline from `/Users/tushar.pandey/.claude/skills/polish-text/SKILL.md`:
`node /Users/tushar.pandey/.claude/skills/polish-text/scripts/visibility.mjs draft.md --audience public --repo <repo> --out <name>.md --dev-out <name>.dev.md`

## Output
Write the drafts to `/Users/tushar.pandey/.local/share/awt/projects/paseo-local/workspaces/paseo-local-main-2/tasks/main/agents/can-you-launch-async-sonnet-subagents-try-async-ag/docs/issues/` as `<repo>-<n>.md` and a final `index.md` listing file, repo and title. Check titles for duplicates with `gh issue list -R tusharpandey13/<repo> --state all --limit 50` (read-only).
