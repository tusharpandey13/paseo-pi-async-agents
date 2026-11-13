---
name: async-agents
description: Launch async subagents (pi-subagents) or, on explicit escalation, Paseo agents. Use when the user says subagent, sub-agent, delegate, parallelize, in parallel, fan out, async/background agent, spin up/have/get another agent, or runs /sonnet /haiku /opus. Resolves model verb, agent, shape, and the awt/pcg briefing.
---

# async-agents

One path for delegation. Follow the steps in order. Do not ask questions the steps already answer.

## 1. Authorization

Delegate only if the user asked for it **in the current request**. Case-insensitive triggers, with the intent of having work done elsewhere:
`subagent`, `sub-agent`, `delegate`, `parallelize`, `in parallel`, `fan out`, `async agent`, `background agent`, `spin up an agent`, `have an agent`, `get another agent`, and the slash prompts `/sonnet`, `/haiku`, `/opus`.

Not triggers: a model name alone ("what is Sonnet's context window?"), task size or complexity, or the existence of a specialist agent. Without a trigger, do the work yourself.

## 2. Model per child

Use the table in [references/verbs.md](references/verbs.md). Always pass `model` explicitly. Never rely on inheritance.

Resolve in this order:
1. An exact `provider/id` the user typed: pass it through unchanged.
2. A per-role verb, e.g. "haiku for scouting, opus for review".
3. A message-wide verb.
4. Default: **sonnet**.

- Two or more verbs with no roles ("use haiku and opus"): ask **one** question and do not launch.
- A misspelled verb ("sonet") maps to the verb it plainly means. Say so in your reply.
- Any other model word ("gpt", "kimi"): run `subagent({action:"models"})`, pick the exact id, and tell the user which one you chose.
- Thinking: append `:low|medium|high|xhigh` only when the user asks ("opus, think hard" gives `:high`).

## 3. Agent

- Default `general`. Use `general-ro` when the task is read-only (research, review, recon, summarize).
- Use builtin roles (`scout`, `reviewer`, `worker`, `oracle`, `researcher`) when the user names one or the shape calls for it. Append the preamble from [references/preamble.txt](references/preamble.txt) to their brief.
- Agents that need extension or MCP tools (mcp, slack, web, paseo, `estimate_cost`) work only as **async** children. Ambient extensions do not load in foreground children.

## 4. Shape

- One task: a single child.
- N independent tasks: `workflow:"parallel"`. Make the briefs differ by seam (file, area, question), never by an index number.
- Dependent steps: a scripted workflow (`subagent({action:"guide"})`, topic workflows).
- Code edits: one writer per cwd. Use `worktree:true` when writers run in parallel or the repo is dirty. Review or gate before accepting.
- Always `async:true`, then **yield**. Do not sleep, poll or call `bg_wait`. The completion notice wakes you.

## 5. Brief (one per child)

Give each child a stable `RUN_KEY` of the form `<seam>-<n>`, e.g. `readme-1`. Use the same value as the workflow `key`. Each brief contains:
- the goal, repo, explicit absolute `cwd` and git ref, and the edit boundary
- the files and evidence to start from
- success criteria and how to validate them
- the line `RUN_KEY: <key>`
- the output file, bound with the call's `output` field as an absolute path: run `echo "$AWT_DIR"` once and pass `<that>/docs/<RUN_KEY>.out.md`. A path written only in the task text does not route output
- when to stop and call `contact_supervisor`
- the awt rule decisions that apply (`awt list decisions --tag rule`, if any)

## 6. awt and pcg (parent side)

- Before launch: `awt note "delegating <RUN_KEY> to <agent> on <verb>: <why>"`. Cost tier is haiku < sonnet < opus.
- On completion: read `$AWT_DIR/docs/<RUN_KEY>.out.md`, then `awt ref` it and `awt decide` anything binding. Only the parent writes `awt state`.
- Report the run's model, usage and cost from the run result.

## 7. Failures

See [references/failures.md](references/failures.md). On any launch or runtime error: stop, report the exact error and run id, and retry the identical call **once**. Never switch to `pi -p`, `pi -ne` or another CLI without approval.

## 8. Control and other features

To stop, steer, resume or check status (U11, U12), and for worktrees, gates, missions, schedules and council, see [references/agents.md](references/agents.md).

## 9. Paseo escalation

Use Paseo agents only on an explicit signal: "keep running after this chat", "new workspace or worktree", "show it in Paseo", "schedule" or "every day", "terminal" or "browser", "on host X". See [references/paseo.md](references/paseo.md). Confirm before creating a schedule, a heartbeat, a writing agent, or more than one Paseo agent.
