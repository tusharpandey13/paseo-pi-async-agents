# Spec: future (GitHub discussion on getpaseo/paseo)

Goal: one discussion (not an issue) on the Paseo GitHub repo `getpaseo/paseo`, category Ideas or Feature requests, asking for parity between pi subagents and native Claude subagents in the subagents list. Evidence: `/Users/tushar.pandey/src/paseo-pi-async-agents/docs/PASEO-PARITY.md`.

The delegated agent only **drafts** it. The parent queues the post with `awt effect plan` for a person to approve.

## Content (all `{pub}`; no local paths, company names, or session talk)
Reproduce each point with public code: find the matching files in the open-source `getpaseo/paseo` repo (`gh api` or `gh search code` read-only; the installed app is 0.16.1, so state the version) and cite repo-relative paths.
1. pi rows have no `subtitle`. Claude rows show `title · Model · Effort · N tokens`. The pi extension's async `status.json` step already carries `model`, `thinking`, `tokens.total`, `totalCost`, `cwd`, `sessionName`.
2. `description` is the whole task text and `title` is the agent name. Ask for a label/short description.
3. Only single `subagent` calls with `agent` and `task` create rows. Workflow scripts, `tasks:[]` parallel and chain calls create none, although their children write `status.json` with `parentWorkflowRunId` and `workflowKey`.
4. `parentSubagentId` and `cwd` are never set for pi rows.
5. The child-transcript follower stops at 200 items or 2 MB.
Ask one question at the end: which of these the maintainers would accept as a PR. Keep it under 350 words, plain, one numbered list.

## Pipeline
Use `/Users/tushar.pandey/.claude/skills/polish-text/SKILL.md`. Draft with a visibility tag on every point, then:
`node /Users/tushar.pandey/.claude/skills/polish-text/scripts/visibility.mjs draft.md --audience public --repo paseo --out discussion.md --dev-out discussion.dev.md`
Then lint the result as the skill describes.

## Output
`/Users/tushar.pandey/.local/share/awt/projects/paseo-local/workspaces/paseo-local-main-2/tasks/main/agents/can-you-launch-async-sonnet-subagents-try-async-ag/docs/paseo-discussion.md` (title on the first line, body below) plus `paseo-discussion.dev.md`. Check for an existing similar discussion or issue first (`gh search issues`/`gh api` read-only, report the URLs if found).
