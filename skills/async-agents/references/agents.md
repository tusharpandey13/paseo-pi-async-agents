# Call shapes

The details live in the `pi-subagents` skill and in `subagent({action:"guide", options:{topic:"<section>"}})`. This page only lists the shape for each feature. Every launch passes `model` and an absolute `output`.

## Launch

```typescript
// single child (U1, U3)
subagent({ agent: "general-ro", model: "<verb id>", async: true,
  task: "<brief>", output: "<AWT_DIR>/docs/readme-1.out.md" })

// N independent children (U2, U8)
subagent({ workflow: "parallel", async: true, args: { tasks: [
  { agent: "general-ro", model: "<id>", task: "<brief: file a>", output: "<AWT_DIR>/docs/a-1.out.md" },
  { agent: "general-ro", model: "<id>", task: "<brief: file b>", output: "<AWT_DIR>/docs/b-1.out.md" },
] } })

// per-role models (U5): a scripted workflow with stable keys
```
```js workflow
const scan = await runs.run("scan-1", { label: "Map auth flow", agent: "scout",
  model: "amazon-bedrock/global.anthropic.claude-haiku-5-5", task: "...", output: "<AWT_DIR>/docs/scan-1.out.md" });
const review = await runs.run("review-1", { label: "Review auth", agent: "reviewer",
  model: "amazon-bedrock/global.anthropic.claude-opus-5-5", task: "... " + scan.output, output: "<AWT_DIR>/docs/review-1.out.md" });
return [scan.outputReference, review.outputReference];
```
Validate a script file before launch with `subagent({action:"validate", workflow:"./x.js"})`.

## Control (U11, U12)

| Need | Call |
|---|---|
| status, fleet, transcript | `subagent({action:"status", id, options:{view:"fleet"\|"transcript"}})` |
| steer a live child | `subagent({action:"steer", id, message})` |
| pause the current turn | `subagent({action:"interrupt", id})` |
| stop (not resumable) | `subagent({action:"stop", id})` |
| continue a finished child | `subagent({action:"resume", id, message})`. This returns a new run id; always resume the latest one. |
| list agents / models | `subagent({action:"list"})`, `subagent({action:"models"})` |
| setup check | `subagent({action:"doctor"})` |

## Other features

| Feature | Where |
|---|---|
| `context: "fork"` (child sees parent history) | guide `tool-reference/fork-context-details` |
| `worktree: true` (parallel writers, dirty repo; needs a clean checkout) | guide `workflows/worktree-isolation` |
| acceptance gates, `output`, `outputMode:"file-only"` | guide `tool-reference/acceptance-gates`, `tool-reference/output-mode-details` |
| `runs.lanes`, rolling fanout, host-command steps | guide `workflows/scripted-workflows` |
| missions and schedules | guide `missions/missions`, `missions/schedules` |
| advisor council | the `council-mode` skill |
| child asks the parent | `contact_supervisor`, guide `workflows/supervisor-coordination-child-asks-parent` |
| prompt shortcuts | `/parallel-review`, `/parallel-research`, `/parallel-cleanup`, `/review-loop` |

## Agents

| Agent | Use | Tools |
|---|---|---|
| `general` | default writer | builtins plus ambient extensions (async only) |
| `general-ro` | read-only work | same, minus `edit` and `write` |
| `scout`, `reviewer`, `worker`, `oracle`, `researcher` | builtin roles | their builtin allowlist plus `estimate_cost` (see `settings.fragment.json`) |

Nesting is off. Children cannot spawn children.
