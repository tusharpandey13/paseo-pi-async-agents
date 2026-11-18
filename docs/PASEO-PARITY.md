# Paseo parity: native Claude subagents vs pi-subagents

Source: Paseo 0.16.1 (`@getpaseo/server` in `Paseo.app/Contents/Resources/app.asar`), checked 2026-11-18 against the live daemon (`listProviderSubagents`, `listCommands`).

How Paseo builds the subagent list: a provider emits `provider_subagent` events into `ProviderSubagentStore` (descriptor: `id, title, description, status, subtitle, toolCallId, cwd, parentSubagentId` plus a per-child timeline). The client shows a pill ("N subagents") and a dropdown row per descriptor. The only subagent requests are list and timeline-get, so neither provider has stop or steer from the UI.

| Aspect | Claude (native) | pi + pi-subagents | Gap |
|---|---|---|---|
| What creates a row | Every Task/Agent call and every workflow (`providers/claude/subagents/live-source.js`, `workflow-replay-source.js`) | Only a `subagent` call with `agent` and `task` and no `action`, plus `resume` (`providers/pi/extensions/pi-subagents/index.js`, `mapSpawn`) | `workflow:true` scripts, `tasks:[]` parallel and chain calls get no row. Fixed on our side by D13 (single calls). |
| Primary line | `description` (short, from the Task call) | `description` = the whole `task` text | Our brief is multi-KB; row starts with its first line. Lever on our side: first line of every brief is a one-line title. |
| Title | explicit `name`, else agent type | agent name (`general-ro`) | No per-child label. |
| Subtitle | `title · Model · Effort · N tokens`, updated live (`presentation.js`) | none (only edxeth's "Needs help") | Model, thinking and tokens never shown. Data exists: each async `status.json` step has `model`, `thinking`, `tokens.total`, `totalCost`, `cwd`, `sessionName`. Needs a Paseo change to read them. |
| Status | edge-triggered task protocol, incl. failed/stopped | polls `status.json` every 250 ms: running, completed, failed, canceled | Equivalent. |
| Child timeline | live sidechain | follows the child session file, capped at 200 items and 2 MB (`child-session.js`) | Long children truncate. |
| Nesting | `parentSubagentId` | never set | Children of a workflow or chain are flat. |
| `cwd` | set | never set | Minor. |
| Slash commands | n/a | Daemon returns `sonnet`, `haiku`, `opus` (kind `command`) and `skill:async-agents` (kind `skill`); client has no filter that hides them | Not reproduced in code; needs a screenshot of the `/so` popup. |

## Path to equivalence
1. Our side (done): N independent children are N single calls (D13).
2. Our side (done, D14): every brief's first line is a short imperative title, since it becomes the row's primary line. Check with `e2e/paseo-subagents.mjs`.
3. Paseo change (upstream PR to getpaseo/paseo, `pi-subagents/index.js`): in `poll()` and `mapSpawn`, emit `subtitle` from the `status.json` step (`model`, `thinking`, `tokens.total`), use the step `sessionName` or `label` as title, and map workflow launches by following `parentWorkflowRunId` and `workflowKey` in child `status.json` files.

## Row check log
Result of `node e2e/paseo-subagents.mjs <parentAgentId> --expect N`, one line per Paseo or pi-subagents upgrade.

| Date | Paseo | pi-subagents | N | Exit |
|---|---|---|---|---|
| 2026-11-18 | 0.16.1 | 0.88.1 | n/a | parity table checked against the live daemon; script not yet run with `--expect` |
