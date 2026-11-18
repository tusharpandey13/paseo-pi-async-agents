---
name: async-agents
description: Launch async subagents (pi-subagents) or, on explicit escalation, Paseo agents. Use when the user says subagent, sub-agent, delegate, parallelize, in parallel, fan out, async/background agent, spin up/have/get another agent, or runs /sonnet /haiku /opus. Resolves model verb, agent, shape, and the awt/pcg briefing.
---

# async-agents

One path for delegation. Follow the steps in order. Do not ask questions the steps already answer.

**If you are a subagent** (`PI_SUBAGENT_CHILD=1`, or your instructions say you are a subagent), stop here. Never delegate and never create Paseo agents, even if your brief repeats words like "parallelize". Do the work yourself, or ask with `contact_supervisor`.

## 1. Authorization

Delegate only if the user asked for it **in the current request**. Case-insensitive triggers, with the intent of having work done elsewhere:
`subagent`, `sub-agent`, `delegate`, `parallelize`, `in parallel`, `fan out`, `async agent`, `background agent`, `spin up an agent`, `have an agent`, `get another agent`, and the slash prompts `/sonnet`, `/haiku`, `/opus`.

Not triggers: a model name alone ("what is Sonnet's context window?"), task size or complexity, or the existence of a specialist agent. Without a trigger, do the work yourself.

## 2. Model per child

Always pass `model` as the **full id** from this table, never the bare verb. Never rely on inheritance.

| Verb | `model` | Paseo `provider` |
|---|---|---|
| sonnet (default) | `amazon-bedrock/global.anthropic.claude-sonnet-5-5` | `pi/amazon-bedrock/global.anthropic.claude-sonnet-5-5` |
| haiku | `amazon-bedrock/global.anthropic.claude-haiku-5-5` | `pi/amazon-bedrock/global.anthropic.claude-haiku-5-5` |
| opus | `amazon-bedrock/global.anthropic.claude-opus-5-5` | `pi/amazon-bedrock/global.anthropic.claude-opus-5-5` |

This table is the only copy of the mapping; update it when models ship. Bedrock ids need the `global.` (or `us.`) prefix. Cost tier: haiku < sonnet < opus. Synonyms such as "cheap" or "best" are not mapped.

Resolve in this order:
1. An exact `provider/id` the user typed: pass it through unchanged.
2. A per-role verb, e.g. "haiku for scouting, opus for review".
3. A message-wide verb.
4. Default: **sonnet**.

- Two or more verbs with no roles ("use haiku and opus"): ask **one** question and do not launch.
- A misspelled verb ("sonet") maps to the verb it plainly means. Say so in your reply.
- Any other model word ("gpt", "kimi"): run `subagent({action:"models"})`, pick the exact id, and tell the user which one you chose.
- Thinking: append `:off|minimal|low|medium|high|xhigh` only when the user asks ("opus, think hard" gives `:high`).

## 3. Agent

- Use `general-ro` for anything that changes no files (research, review, recon, summarize, answer). Use `general` only when the child edits files.
- Use builtin roles (`scout`, `reviewer`, `worker`, `oracle`, `researcher`) when the user names one or the shape calls for it. Append the preamble from [references/preamble.txt](references/preamble.txt) at the **end** of their brief (custom agents already carry it).
- Agents that need extension or MCP tools (mcp, slack, web, paseo, `estimate_cost`) work only as **async** children. Ambient extensions do not load in foreground children.

## 4. Shape

- One task: a single child.
- N independent tasks: **N separate single `subagent` calls in the same reply**, each with `agent`, `model`, `async:true`, `task` and an absolute `output`. Paseo shows only single `agent`+`task` calls as subagent pills (with model and tokens); a workflow script (`runs.all`, `workflow:true`) is invisible there. The runs still execute in parallel. Make the briefs differ by seam (file, area, question), never by an index number.
- Dependent steps: launch step 1 as a single call, yield, and launch step 2 from the completion notice, so each step is a pill. Use a scripted workflow (`subagent({action:"guide"})`, topic workflows) only under the workflow guard below.
- Workflow guard: when a request names a workflow script ("as a workflow", `runs.all`, `workflow:true`, `tasks:[]`, a script file), do not launch it yet. First tell the user that Paseo will not list the workflow's children, so they cannot be tracked or opened there. Offer N single `subagent` calls instead, each with `agent`, `task`, `async:true` and `output`, and wait for the answer. Launch the workflow only after the user confirms it, or when the logic needs loops or gates (then state the missing rows in the same reply). After a confirmed workflow launch, say that no Paseo rows are expected for it.
- Code edits: one writer per cwd.
  - Parallel writers need `worktree:true`, which requires a **clean** checkout. If the repo is dirty, use a single writer in the shared cwd, or ask the user to commit or stash.
  - Managed worktrees are removed when the run ends. Uncommitted edits survive only as the patch listed in the result's `artifactPaths` (`worktree-diffs/`). Tell a worktree writer to commit on its branch, or apply the patch yourself after review.
  - Gate writers: `options.gate: "<test command>"` for one command, or `options.acceptance: {level:"checked", evidence:["changed-files","commands-run"]}`. In a workflow `runs.run` item, `acceptance` is a plain field. For an independent review, launch `reviewer` on the diff after the writer completes, and accept only after it passes.
- Always `async:true`, then **yield**. Do not sleep, poll or call `bg_wait`. The completion notice wakes you.

## 5. Brief (one per child)

First run `echo "$AWT_DIR"` once. Call the result `OUT`: `$AWT_DIR/agents` when it is set. When it is empty (no awt), use `/tmp/async-agents/agents` (run `mkdir -p` on the child's directory) and skip every awt step below. Each child's output is `<OUT>/<RUN_KEY>/out.md`.

Give each child a stable `RUN_KEY` of the form `<seam>-<n>`, e.g. `readme-1`. Other sessions share `OUT`, so run `ls "$OUT"` once and pick the first `n` with no `<seam>-<n>` entry there (awt makes `agents/<RUN_KEY>` as the child's node). Use the same value as the workflow `key` if you do use a workflow. Each brief contains, in this order:
- **line 1: a short imperative title** (at most 60 characters, no path, no key), e.g. `Map auth flow in api-js`. Paseo shows the start of the task text as the child's row label, so the title must come first.
- line 2: `RUN_KEY: <key>`, and line 3: `MODEL: <exact model id passed in the call's model field>`. awt reads both only within the first 5 lines, so keep them there. MODEL must be a plain id (letters, digits, `._:/@+-[]`, at most 200 characters, no spaces) or awt ignores it. For a builtin agent the preamble still goes at the end
- the goal, repo, explicit absolute `cwd` and git ref, and the edit boundary
- the files and evidence to start from
- success criteria and how to validate them
- the output file, bound with the call's `output` field as the absolute path `<OUT>/<RUN_KEY>/out.md`. A path written only in the task text does not route output. A harness without hooks can run `awt init --child <RUN_KEY>` (idempotent) before launch and pass the printed `AWT_DIR` and `AWT_BY` to the child
- for a child on the Claude provider (no pi hook): `awt-node: $AWT_DIR/agents/<RUN_KEY>` (the absolute path), and "pass `--dir <that path>` on every call of awt"; its output is `<that path>/out.md`
- when to stop and call `contact_supervisor`
- never an instruction to delegate. If the user wants nested fan-out, run every child from this session instead; a brief cannot override the child's never-delegate rule
- the awt rule decisions that apply (`awt list decisions --tag rule`, if any)

## 6. awt and pcg (parent side)

- Before launch: `awt note "delegating <RUN_KEY> to <agent> on <verb>: <why>"`. Cost tier is haiku < sonnet < opus.
- On completion: read the result's `savedOutputPath` (normally `<OUT>/<RUN_KEY>/out.md`), then `awt ref` it and `awt decide` anything binding. Only the parent writes `awt state`.
- Report each child's model, and its cost if the completion shows it. Do not make extra calls to find cost: pcg's history records every child's usage.

## 7. Failures

See [references/failures.md](references/failures.md). On a transient launch or runtime error: stop, report the exact error and run id, and retry the identical call **once**. A validation error (unknown model, unknown agent, bad field) is not retried: report it with the closest valid options and ask. Never switch to `pi -p`, `pi -ne` or another CLI without approval.

## 8. Control and other features

To stop, steer, resume or check status (U11, U12), and for worktrees, gates, missions, schedules and council, see [references/agents.md](references/agents.md).

## 9. Paseo escalation

Use Paseo agents only on an explicit signal: "keep running after this chat", "new workspace or worktree", "show it in Paseo", "schedule" or "every day", "terminal" or "browser", "on host X". See [references/paseo.md](references/paseo.md). Confirm before creating a schedule, a heartbeat, a writing agent, or more than one Paseo agent.
