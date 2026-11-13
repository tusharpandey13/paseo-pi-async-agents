# Spec: seamless async subagents for pi + Paseo

Status: v1 built (see section 12 for what is verified).  Items marked **[verify]** are assumptions that the E2E plan in section 9 must confirm.
Terms: **awt** is a per-task work-record CLI (notes, decisions, refs, an outbox for anything that leaves the machine). **pcg** is a cost governor extension for pi that adds an `estimate_cost` tool and records usage. **Paseo** is the agent workspace app with an MCP server.
Scope: pi coding agent with the `pi-subagents` extension, running Claude models on Amazon Bedrock, inside Paseo.

## 1. Problem and goals

Launching a simple async subagent took many attempts because the rules were scattered: exact `provider/id` model strings, the Bedrock `global.` prefix, strict child tool allowlists, a "delegate only when asked" rule, and the failure and retry policy.
- G1. A phrase such as "do this in a subagent", "parallelize", "delegate" or "fan out" launches async children with no further questions, on **Sonnet** by default.
- G2. A model verb in the chat (`sonnet`, `haiku`, `opus`) selects that model. An explicit verb always wins over the default.
- G3. Children can use tools beyond the strict builtin allowlist (mcp, slack, web search, paseo, `estimate_cost`).
- G4. Every child is governed by the cost governor (pcg) and the work record (awt), consistent with the parent.
- G5. Everything `pi-subagents` supports stays reachable: parallel, workflows, resume/steer/stop, worktrees, gates, missions, schedules, council.
- G6. Paseo MCP is an explicit escalation path with a clear "when to use" rule.
- Non-goals: Claude Code, Codex or Cursor wrappers; changing `pi-subagents` internals; models other than the three verbs unless the user names an exact id.

## 2. Decisions

These are fixed for v1.

| # | Decision | Consequence |
|---|---|---|
| D1 | Keep `pi-subagents` as the default delegation engine. | Paseo agents are escalation only. |
| D2 | Omit `tools` on custom agents so background children get extension tools. Custom agents set `async: true`. | pi-subagents 0.88.1 docs confirm: ambient extensions load only in background children; foreground children never load them, and a foreground launch needing ambient MCP tools fails. Async is therefore required, not a preference. Fall back to an explicit allowlist only if E5 shows the tools are missing. |
| D3 | Use settings, not ejected copies, to change builtin agents. `subagents.defaultInheritGlobalContext: true` plus `agentOverrides.<name>.tools` / `.inheritGlobalContext`. | `pi-subagents` documents both: `defaultInheritGlobalContext` is a settings key, and `inheritGlobalContext` and `tools` are supported override fields. No eject step. |
| D4 | Keep the ambient safety extensions on in children (best judgement). | Observed behavior is fail-closed without a UI: `permission-gate` blocks `rm -rf`, `sudo`, `chmod 777` and returns "no UI for confirmation"; `protected-paths` blocks writes to `.env`, `.git/`, `node_modules/`; `dirty-repo-guard` only hooks session switch and fork, and `git-checkpoint` only hooks fork and turn events. A child that needs a blocked action asks the parent with `contact_supervisor`. Tune with `defaultExtensions` / `subagentOnlyExtensions` only if E7 shows a legitimate block. |
| D5 | pcg records child usage in its history. | The parent summary still reports run-level cost from the run result, and E6 asserts the history line. |
| D6 | Pin a Paseo agent's model with `provider: "pi/<bedrock model id>"` and `settings.thinkingOptionId`. | See section 6.2. |
| D7 | Always pass an explicit `model`. Never rely on inheritance. | The parent may be on a different model. |
| D8 | Verbs map to Sonnet 5.5 (default), Haiku 5.5, Opus 5.5 on the Bedrock `global.` inference profile. | See section 5.1. |
| D9 | A Paseo plugin is not part of v1. A small optional plugin is a phase-2 candidate. | See section 7. |
| D10 | Dev and E2E keep the exact Bedrock ids and mock them. `dev/models.mock.json` overrides the three `amazon-bedrock` models to DeepSeek's OpenAI-compatible endpoint with `samplingParams.model: "deepseek-flash"`, merged only into an isolated `PI_CODING_AGENT_DIR` (`install.sh --dev` refuses the default dir). | Every E2E exercises the production id strings, the session records them, and the work is done by `deepseek-flash` at about $0.0001 per tiny call. Virtual models (`registerVirtualModel`) cannot be used: pi rejects them because the ids exist as physical Bedrock models. |
| D11 | Bind each child's result file with the call's `output` field (absolute path), not with an instruction in the task text. | pi-subagents only routes output through `output`. For read-only children the runtime persists the final response; writers get a direct-write instruction. The child preamble says "your final response is your result". |

## 3. Findings that shape the design

Observed by probing a read-only `delegate` child on `amazon-bedrock/global.anthropic.claude-sonnet-5-5`.

| Fact | Consequence |
|---|---|
| Child env contains the parent's `AWT_DIR` and `AWT_BY`, plus `PASEO_AGENT_ID`, `PI_SUBAGENT_CHILD=1`, `PI_SUBAGENT_PARENT_SESSION`. | Children share the parent's awt node. Two parallel children writing `$AWT_DIR/out.md` clobber each other and the node's handoff. Each child needs its own output path and its own `--by`. |
| `awt` is on the child's PATH. | The child can run awt, so the rules are enforced by instruction, not by absence. |
| Child tools are `read grep find ls bash edit write contact_supervisor`. There is no `estimate_cost` and no `awt_resume`. | pcg's tool is blocked by the allowlist. |
| The child's prompt carried the `[governor ...]` note. | pcg hooks load in background children. Only the tool is missing. |
| The child has no `AGENTS.md` content, global or project. | Global rules (awt, signed commits, absolute paths, account selection, artifact pipeline) do not reach children until `inheritGlobalContext` is on. |
| Child thinking level was `medium` while the parent ran `high`. | Thinking is a separate knob. Verbs set the model only. |
| Model ids must be exact `provider/id`. Bedrock needs a `global.`, `us.` or similar prefix. | The verb table stores full ids. |

Children launched by `pi-subagents` are pi-internal sessions. They are not Paseo agents, get no awt node of their own, and are invisible to a Paseo plugin.

## 4. Architecture

```
user phrase / slash prompt
        |
  [async-agents skill]  resolves: authorization, verb->model, agent, shape, awt/pcg briefing
        |
  +-----+----------------------------+
  | pi-subagents (default)           |  Paseo MCP (escalation, explicit)
  | subagent({agent,model,async})    |  paseo_create_agent(provider:"pi/<model>",...)
  +----------------------------------+
        |
  custom agents general, general-ro  +  builtin agents patched via settings
```

Components. All are new files in this repo, installed by symlink (section 11).
- `skills/async-agents/SKILL.md` (which holds the verb table) with `references/agents.md`, `preamble.txt`, `paseo.md` and `failures.md`. The awt/pcg briefing is short enough to live in SKILL.md section 6.
- `prompts/{sonnet,haiku,opus}.md`: a slash command is explicit authorization plus an explicit verb.
- `agents/{general,general-ro}.md`.
- `settings.fragment.json`: the `subagents` block to merge into `~/.pi/agent/settings.json`.
- `agents-md.fragment.md`: a one-line pointer for `~/.pi/agent/AGENTS.md`.
- `install.sh`: idempotent symlinks into `<agent-dir>/{skills,prompts,agents}`, a settings merge with a backup, and an `AGENTS.md` pointer. Dry run by default; `--apply`, `--agent-dir`, `--dev`.
- `dev/models.mock.json` (D10) and `e2e/{setup.sh,run.sh,fixtures/}`: the isolated E2E environment.

## 5. Dev spec

### 5.1 Verb table (single source of truth: the table in `SKILL.md`)

E1 showed that a parent which only had a pointer to a separate verbs file passed the bare verb (`model: "sonnet"`), was rejected, and recovered through `models`. The table is therefore inlined in SKILL.md.

| Verb | Model id |
|---|---|
| sonnet (default) | `amazon-bedrock/global.anthropic.claude-sonnet-5-5` |
| haiku | `amazon-bedrock/global.anthropic.claude-haiku-5-5` |
| opus | `amazon-bedrock/global.anthropic.claude-opus-5-5` |

- The skill always passes `model` explicitly.
- Optional thinking suffix `:minimal|low|medium|high|xhigh` is appended only when the user says so ("opus, think hard" gives `:high`). Otherwise the agent's own `thinking` applies.
- A user-supplied exact `provider/id` is passed through unchanged.
- Any other model word (for example "gpt", "kimi", "nova"): run `subagent({action:"models"})`, choose the exact id, and tell the user which one was chosen.
- Synonyms such as "cheap" or "best" are not mapped. Add them only on request.

### 5.2 Authorization and trigger resolution

Delegation is allowed only when the user asked for it in the current request. Triggers are case-insensitive and the intent must be to have work done elsewhere: `subagent`, `sub-agent`, `delegate`, `parallelize`, `in parallel`, `fan out`, `async agent`, `background agent`, `spin up an agent`, `have an agent`, `get another agent`, and the slash prompts `/sonnet`, `/haiku`, `/opus`.
Not triggers: a verb alone ("what is Sonnet's context window"), the size or complexity of the task, or the availability of a specialist agent.

Resolution order:
1. Authorization present? If not, do the work directly.
2. Model per child: explicit exact id, then per-role verb ("haiku for scouting, opus for review"), then message-wide verb, then default Sonnet.
3. Ambiguous mapping (for example "use haiku and opus" with no roles): ask one question. Do not guess.
4. Agent: default `general`, or `general-ro` when the task is read-only (research, review, recon). Use builtin roles (`scout`, `reviewer`, `worker`, `oracle`, `researcher`) when the user names one or the shape calls for it.
5. Shape: one task is a single child. N independent tasks use `workflow:"parallel"`. Dependent steps use a scripted workflow. Code edits use a single writer per cwd, or `worktree:true`.
6. Always `async:true`, then yield. No sleeping, no polling, no `bg_wait` for native async runs.

### 5.3 Settings (`settings.fragment.json`)

```jsonc
{
  "subagents": {
    "defaultModel": "amazon-bedrock/global.anthropic.claude-sonnet-5-5",
    "defaultInheritGlobalContext": true,
    "agentOverrides": {
      // builtin roles keep their prompts; they gain pcg's tool and the global context
      "scout":      { "tools": ["read","grep","find","ls","bash","write","contact_supervisor","estimate_cost"] },
      "reviewer":   { "tools": ["read","grep","find","ls","watchdog_diff","contact_supervisor","estimate_cost"] },
      "worker":     { "tools": ["read","grep","find","ls","bash","edit","write","contact_supervisor","estimate_cost"] },
      "oracle":     { "tools": ["read","grep","find","ls","bash","estimate_cost"] },
      "researcher": { "tools": ["read","write","web_search","fetch_content","get_search_content","source_check","estimate_cost"] }
    }
  }
}
```
- The allowlists are the builtin frontmatter of pi-subagents 0.88.1 plus `estimate_cost`. `tools` overrides replace the list, so E19 re-diffs them after each upgrade. `tools: "inherit"` was rejected: it gives read-only roles `edit`/`write` and drops `watchdog_diff`.
- Each builtin override also sets `subagentOnlyExtensions: [<pcg extension file>]`. E20 (dev) showed that without it, a foreground launch of a patched builtin is rejected ("foreground child never loads the parent's ambient extensions ... unavailable: estimate_cost"). That would break every foreground use of those builtins, not only this skill's. With it, foreground and background both get `estimate_cost`, and no double-load error occurs. `install.sh` fills the path from the agent dir's packages (`package.json` name `pcg`), or from `--pcg PATH`. If pcg is absent, it drops both `estimate_cost` and the extension entry so builtins keep working.
- `defaultModel` is a fallback only. The skill still passes `model` explicitly (D7).
- `defaultInheritGlobalContext: true` applies to every builtin, package, user and project agent. An agent that sets `inheritGlobalContext: false` still opts out. It only has effect for agents with `inheritProjectContext: true`, which every builtin has.
- Nesting stays off: `allowNestedSubagents` is not set, so children never spawn children.
- Unknown override keys fail loading with a "Did you mean" error, so a typo is caught at startup.
- Existing keys in `settings.json` (extensions, packages, models) are preserved by the merge.

### 5.4 Custom agents

`agents/general.md`

```yaml
---
name: general
description: General delegate with ambient tools (mcp, web, slack, paseo), pcg and awt rules
async: true
systemPromptMode: append
inheritProjectContext: true
inheritGlobalContext: true
inheritSkills: true
# tools omitted: builtins plus ambient extension tools in background children (D2) [verify]
thinking: medium
---
<child preamble: section 5.5>
```
`acceptanceRole` is omitted on `general`. With `writer`, E1's no-file task inferred a checked acceptance that required changed-files evidence and a reviewer, and was marked `rejected`. The skill passes `gate` or `acceptance` explicitly for code edits instead.
`agents/general-ro.md`: same, plus `excludeTools: edit, write` and `acceptanceRole: read-only`. The skill uses it for every task that changes no files. `bash` can still mutate, so the preamble forbids mutation.
E5 (dev) result: omitted `tools` gives Pi's default set, not the builtin agents' set, so `general-ro` had `read, bash, bg_wait, estimate_cost, contact_supervisor`. There was no `grep`, `find` or `ls`, and `bash` covers them. Extension tools (`estimate_cost`) are present, and the strict `delegate` control lacks them, which confirms D2.
Fallback if a Bedrock-machine E5 shows omitted `tools` hides extension tools: an explicit allowlist `read, grep, find, ls, bash, edit, write, contact_supervisor, estimate_cost, web_search, fetch_content, get_search_content, mcp, mcp:slack, mcp:paseo`.

### 5.5 Child preamble (identical in every custom agent; appended to briefs for builtin agents)

```
You are a subagent of $AWT_BY. Do not run `awt resume`, `awt state`, `awt status`, or `awt effect apply`.
Your final response is your result; the runtime saves it to $AWT_DIR/docs/<RUN_KEY>.out.md (RUN_KEY is in your brief), so make it complete. Never write $AWT_DIR/out.md or anything under .awt/.
If you record anything, use `awt note --by sub:<RUN_KEY> "..."`. Anything that leaves this machine goes through `awt effect plan` only; a person approves it.
Before a task that will use tools, call estimate_cost. Follow the global rules you inherited (signed commits, absolute paths, account selection).
If a gate blocks a needed action, do not work around it. Call contact_supervisor with reason need_decision.
```
The skill injects a stable `RUN_KEY` (for example `scan-1`) into each brief and into the workflow `key`. Separate parent sessions share `$AWT_DIR`, and E2 and E18 both chose `reply-1` and overwrote each other's file, so the skill picks the first `n` whose output file does not exist. For builtin agents the preamble goes at the end of the brief, because pcg labels history lines with the start of the task.

### 5.6 Briefs (generated by the skill)

A brief contains: goal, repo, explicit `cwd` and ref, edit boundary, files and evidence, success criteria, validation, the output path `$AWT_DIR/docs/<RUN_KEY>.out.md` (passed as the absolute `output` field, D11), when to stop and ask, and the awt `rule` decisions that apply (`awt list decisions --tag rule`).
Parallel briefs differ by seam, never by an index number.

### 5.7 Parent-side awt and pcg behavior

- Before launch: `awt note "delegating <RUN_KEY> to <agent> on <verb>: <why>"`.
- After completion: read `docs/<RUN_KEY>.out.md`, then `awt ref` it and `awt decide` anything binding. The parent owns `state`.
- pcg: the parent keeps calling `estimate_cost` for its own work. The launch note records the child's model and cost tier (haiku < sonnet < opus). The completion summary reports cost when the completion shows it. The parent cannot always see child usage (dev E5), so pcg history is the record. E6 (dev) passed: each child appears in `governor-history.jsonl` with its own model and usd.
- Pending children count as a certain wake for pcg, so the cache stays warm while they run.

### 5.8 Failure playbook (`references/failures.md`)

| Symptom | Fix |
|---|---|
| `Unknown subagent model` | Use the verb-table id, else `subagent({action:"models"})`. |
| `on-demand throughput isn't supported` | The id lacks the `global.` or `us.` prefix. |
| Extension tool missing in a child | Use `general`, or add the tool to `tools` and its extension to the child's allowlist. |
| Child lacks global rules | The agent has `inheritGlobalContext: false`, or the setting is not applied. |
| Child blocked by `permission-gate` or `protected-paths` | The child calls `contact_supervisor`. The parent runs the action itself or approves a narrower command. |
| Validation error before launch (unknown model, agent or field) | No retry: report the error with its closest options and ask. E13 (dev) showed retrying a deterministic rejection is waste. |
| Worktree writer's edit missing | Managed worktrees are removed at completion; apply the saved `worktree-diffs` patch or have the writer commit (E15). |
| Any other launch or runtime failure | Stop, report the exact error and run id, retry the same call once. Do not switch to `pi -ne` or another CLI without approval. |

### 5.9 Prompt templates

`prompts/sonnet.md`, `haiku.md`, `opus.md`, for example:

```
---
description: Delegate to an async subagent on Haiku
---
Load the `async-agents` skill. The user explicitly asks to delegate and to use model verb `haiku`. Task: $@
```

### 5.10 Coverage of `pi-subagents` features (G5)

Single child; parallel; scripted workflow (`runs.run/all/lanes`, resume keys); `resume`, `steer`, `interrupt`, `stop`, `status` (fleet, transcript), `doctor`, `models`, `validate`; `context: fork|fresh`; `worktree:true`; acceptance gates and `output`; missions and schedule controls; the council-mode skill; `contact_supervisor`; prompt shortcuts (`/parallel-review`, `/parallel-research`, `/parallel-cleanup`, `/review-loop`).
`references/agents.md` lists the call shape for each and defers deep detail to the `pi-subagents` skill and `subagent({action:"guide"})`.

## 6. Paseo MCP

### 6.1 Benefits and judgment

Benefits:
1. Detached lifetime. A Paseo agent survives the chat. `pi-subagents` children die with the session.
2. Workspace isolation. `paseo_create_workspace` supports worktree, branch and PR checkout.
3. Visibility and control. Agents show in the Paseo UI, permission prompts surface (`list_pending_permissions`, `respond_to_permission`), and `cancel`, `kill`, `archive` and mode switching are available.
4. awt-native. The awt Paseo plugin gives each Paseo agent its own node nested under the parent (label `paseo.parent-agent-id`), sets `AWT_DIR` and `AWT_BY`, and provides `awt_resume`. This is the only path where a child is a first-class awt participant.
5. Automation. `create_schedule`, `create_heartbeat`, `notifyOnFinish`, workspace scripts, terminals, browser automation, and multi-host `serverId`.

Costs and limits:
- Only provider `pi` is enabled. Other providers (claude, codex, copilot, opencode, omp, antigravity, muse) are unavailable, so there is no model diversity beyond Bedrock.
- Every Paseo agent is a fresh pi session with no fork context and a cold prompt cache. A cold start is the expensive case.
- There are no acceptance gates, scripted workflows, retained-child resume or fan-out budgets. Coordination is by prompt.
- The MCP surface has 63 tools. Connect lazily with `mcp_connect` and call through the `mcp` proxy. Do not load the whole schema into context.
- Write power (create or kill agents, schedules, terminals) has a high blast radius.

Judgment:
- Not the default. `pi-subagents` is faster and cheaper for in-session fan-out (fork context, shared cache behavior, gates, retries) and more controllable.
- Use Paseo agents only on explicit signals: "keep running after this chat", "in a new workspace or worktree", "show it in Paseo", "schedule" or "every day", "terminal" or "browser", "on host X".
- Always confirm before creating a schedule, a heartbeat, an agent that writes, or more than one Paseo agent.

### 6.2 Pinning a model on `paseo_create_agent`

The tool's `provider` field is a "provider/model" pair (schema example `codex/gpt-5.4`). `paseo_list_models` for provider `pi` returns 202 entries whose `id` is `amazon-bedrock/<bedrock model id>`, including all three verb ids. Therefore the pin is:

```jsonc
{
  "title": "Review auth diff",
  "provider": "pi/amazon-bedrock/global.anthropic.claude-sonnet-5-5",
  "settings": { "thinkingOptionId": "medium" },
  "initialPrompt": "...",
  "labels": { "async-agents.verb": "sonnet", "async-agents.run-key": "review-1" },
  "notifyOnFinish": true
}
```
- Thinking options per model come from `paseo_list_models` (`off`, `minimal`, `low`, `medium`, `high`, and on newer Claude models `xhigh`, `max`). Default is `medium`.
- Same verb table as 5.1. Paseo ids carry the prefix `pi/`.
- Derived from the tool schema and the model listing. Not yet exercised: E17 asserts the created agent reports the pinned model.
- Fallback if the combined form is rejected: `provider: "pi"` plus a model field in `settings`, then set the model after creation. Record the working form in `references/paseo.md`.

## 7. Would a Paseo plugin help?

Short answer: not for the core goal, and optionally for a narrow phase-2 slice.

Why not for v1:
- The core path is `pi-subagents`, whose children are pi-internal sessions. A Paseo plugin hooks Paseo agents and workspaces. It cannot see or shape those children.
- The things that make children seamless (model verbs, tools, global context, awt/pcg briefing) live in pi: skill, prompts, agent files and settings. A plugin adds nothing there.
- Tool and MCP injection at `agent.session_open` is unnecessary. The needed tools already load as ambient pi extensions.
- The existing awt Paseo plugin already gives Paseo agents their awt node and `awt_resume`.

What a plugin could add later, for Paseo-level agents only:

| Capability | Mechanism | Value |
|---|---|---|
| Default model and thinking for new `pi` agents | `server.before("agent.create")` rewrites the saved config | Enforces "Sonnet unless a verb is given" in code instead of prompt discipline. Highest value. |
| Verb shortcuts in the Paseo composer | `addSlashCommand` for `/sonnet`, `/haiku`, `/opus` (client code, not a prompt) | Needs a check that a command can create an agent or send a prompt. Without that it only sets state. |
| Visible default verb | `addComposerPill` showing and toggling the active verb | Convenience. |
| Spawn audit | `server.on` lifecycle events logging agent creation and finish | Cost visibility for Paseo-created agents. |

Recommendation: build nothing now. After E17 shows how often agents are created without a pinned model, decide whether the `agent.create` hook alone is worth a small plugin. Extend the existing awt plugin rather than adding a second one. Research item: whether Paseo's "Subagents" composer pill can surface `pi-subagents` runs, which would give children UI visibility without a plugin.

## 8. Journeys

### 8.1 User journeys

| ID | User says | Expected |
|---|---|---|
| U1 | "do this in a subagent: summarize README" | `general-ro`, Sonnet, async, yield. Result summarized on wake. |
| U2 | "parallelize: review these 3 files" | `workflow:"parallel"`, 3 children on Sonnet, one per file, aggregated reply. |
| U3 | "delegate the lint fix to haiku" | `general` writer (or `worker`), Haiku explicit. |
| U4 | "/opus review this diff" | Slash is authorization plus Opus. `reviewer` or `general-ro`, read-only. |
| U5 | "haiku scouts, opus reviewer" | Per-role models: scout Haiku, reviewer Opus. |
| U6 | "use haiku and opus" (no roles) | One clarifying question. |
| U7 | "what's the difference between sonnet and haiku?" | No launch. |
| U8 | "fan out 4 agents to search slack for X" | `general` x4 with the slack tool, all Sonnet. |
| U9 | "run this in the background after we close the chat, in its own worktree" | Paseo escalation: confirm, then create workspace and agent. |
| U10 | "every weekday 9am check CI" | Paseo schedule, after confirmation. |
| U11 | "stop that agent" / "tell it to also check tests" | `stop` / `steer` by run id. |
| U12 | "continue the previous child's work" | `resume` on the latest run id. |
| U13 | "do the migration in a subagent" (writes code) | Single writer. `worktree:true` if the repo is dirty or writers are parallel. Gate or review before accept. |

### 8.2 Agent journeys

- A1 parent, happy path: detect trigger, resolve verb, pick agent and shape, `awt note`, `subagent` async with RUN_KEY and briefing, yield, on notice read `docs/<RUN_KEY>.out.md`, report, `awt ref`.
- A2 child: read brief, skip awt resume, `estimate_cost`, work, write `docs/<RUN_KEY>.out.md`, final response summary.
- A3 child blocked: `contact_supervisor` with `need_decision`, stay alive for the reply.
- A4 failure: transient launch error, stop, report run id and error, retry once identically, then ask the user. Validation errors skip the retry.
- A5 parallel writers: refuse a shared cwd, use `worktree:true` per lane, merge and clean up only after review.
- A6 Paseo escalation: `mcp_connect paseo`, `paseo_create_workspace`, `paseo_create_agent` with the pinned provider and `notifyOnFinish:true` and labels, `awt ref paseo:agent/<id>`, yield.

## 9. E2E plan

Environment (D10): `e2e/setup.sh` builds `/tmp/ppaa-e2e/agent` (pi-subagents 0.88.1, pcg, this repo installed with `--dev`, fixture `AGENTS.md` carrying the canary rule "commits must be signed, `-S`") and a scratch awt node `/tmp/ppaa-e2e/awt-node`. `e2e/run.sh <ID> "<prompt>"` runs one headless parent turn on the mocked Sonnet id. All verbs route to `deepseek-flash`, so E2/E3 check the requested id, not model behavior. E17 needs Paseo to launch pi against the real agent dir, so it runs on the Bedrock machine only.
Cheap first: tiny tasks. Evidence sources: `subagent({action:"status"})`, the child `session.jsonl`, `$AWT_DIR/docs`, `awt doctor`, and the pcg history file.

| ID | Scenario | Pass criteria |
|---|---|---|
| E1 | "do this in a subagent: reply foo bar" | Child model is Sonnet 5.5; async; parent yields without polling; output "foo bar". |
| E2 | Same with "using haiku" / "using opus" | Child model matches the verb exactly. |
| E3 | "haiku scouts, opus reviewer" (2 children) | Each child's model matches its role. |
| E4 | "parallelize" 3 tiny tasks | 3 runs, distinct keys, aggregated; no shared output file. |
| E5 | Tool access: `general` calls `mcp({server:"paseo"})` status and `web_search`. A builtin `delegate` runs the same call as a control. | Both succeed in `general`; the control fails. Decides D2. |
| E6 | pcg: child calls `estimate_cost` | Tool present, returns "Recorded", and a line appears in the pcg history file (D5). |
| E7 | awt and gates: child writes `$AWT_DIR/docs/<RUN_KEY>.out.md` with ambient extensions on; no `state`, no `.awt/` edits, no `out.md` | File exists; `awt doctor` clean; node `state` unchanged; no gate blocked the write. Decides D4. |
| E8 | awt: 3 parallel children | 3 distinct out files, none overwritten, notes attributed `sub:<key>`. |
| E9 | Global rules reach the child: ask "what must be true of commits?" | Answers "signed, `-S`". Fails without `inheritGlobalContext`. Decides D3. |
| E10 | U7 negative | No `subagent` call. |
| E11 | U6 ambiguity | Exactly one clarifying question, no launch. |
| E12 | Bad model word "sonet" | Skill resolves via the verb table or `models`, or asks. Never sends a bare id. |
| E13 | Forced launch failure (invalid id) | Stop, report with closest ids, no retry (validation error), no other CLI. |
| E14 | `steer` and `stop` a long child | State transitions observed; `resume` returns a new run id. |
| E15 | Writer in a scratch git repo with `worktree:true` | Child edits in the worktree; main tree untouched; the edit is recoverable (commit on the branch or saved patch). |
| E16 | Nested spawn attempt by a child | Denied. |
| E17 | Paseo escalation (U9) | Asks first. Creates workspace and agent with `provider: "pi/amazon-bedrock/global.anthropic.claude-sonnet-5-5"`. `paseo_get_agent` reports that model. awt node nested under the parent. No schedule without consent. Decides D6. |
| E18 | Slash prompts `/haiku`, `/sonnet`, `/opus` | Authorized without extra phrasing; model matches. |
| E19 | Regression after a `pi-subagents` upgrade | Rerun E1, E5, E7, E9, and diff builtin allowlists against `settings.fragment.json`. |
| E20 | Foreground and background launch of a patched builtin (`scout`) | Both launch and have `estimate_cost` (needs `subagentOnlyExtensions`, 5.3). |

Unit-level checks with no model calls: `subagent({action:"validate"})` on any shipped workflow file; agent frontmatter parses (`subagent({action:"list"})` shows `general` and `general-ro`); `settings.json` is valid JSON after the merge; `subagent({action:"models"})` lists all three verb ids; `install.sh` dry run prints the planned links and a settings diff.

## 10. Risks and open questions

1. D2 is a decision, but the mechanism is **[verify]** in E5. The fallback allowlist is specified in 5.4.
2. Builtin `tools` overrides replace the list. The lists are pinned to 0.88.1; an upgrade that adds a builtin tool is lost until E19 re-diffs them.
3. D4 is a judgment call. If E7 shows `permission-gate` blocking legitimate cleanup (`rm -rf` of a temp dir), the child must ask the parent. That is acceptable friction and keeps the fail-closed property.
4. Shared `AWT_DIR` and `AWT_BY` is the largest awt risk. It is mitigated by per-run output paths and `--by`. The clean fix is upstream: give each child its own sub-node, in the same way the awt Paseo plugin does for Paseo agents.
5. Sonnet for everything ignores cost tiers. Auto-suggesting Haiku for pure recon is off by default because the requirement is "auto Sonnet".
6. `thinking: medium` on `general` can be too low for review work. The caller can pass a `:high` suffix per run.
7. Paseo model pin (6.2) is derived from schema and listing, not yet exercised.
8. Verb ids will drift as new models ship. The SKILL.md table is the only place to update, and E19 catches stale ids.

## 11. Rollout and repository layout

```
paseo-pi-async-agents/
  README.md
  docs/SPEC.md                      this document
  skills/async-agents/{SKILL.md,references/,scripts/smoke.md}
  prompts/{sonnet,haiku,opus}.md
  agents/{general,general-ro}.md
  settings.fragment.json
  agents-md.fragment.md
  dev/models.mock.json              Bedrock ids -> deepseek-flash, isolated agent dir only (D10)
  e2e/{setup.sh,run.sh,fixtures/}   isolated E2E environment
  install.sh                        symlinks into <agent-dir>/{skills,prompts,agents}; merges settings; AGENTS.md pointer; --apply to write
```
1. Agents, settings fragment and preamble. Run E1, E5, E6, E7, E9 to settle D2 to D5.
2. Skill, references and prompt templates. Run E1 to E4, E10 to E13, E18.
3. Paseo reference. Run E17 with confirmation and settle D6.
4. `AGENTS.md` pointer. Keep E19 as the standing regression runbook.
5. Decide on the phase-2 plugin after E17 (section 7).
