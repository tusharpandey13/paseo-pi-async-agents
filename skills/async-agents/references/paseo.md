# Paseo escalation

Paseo is not the default. Use a Paseo agent only when the user says something like: "keep running after this chat", "in a new workspace or worktree", "show it in Paseo", "schedule" or "every day", "terminal" or "browser", or "on host X".

Always confirm first before creating a schedule, a heartbeat, an agent that writes, or more than one agent.

## Steps (A6)

1. Reach the `paseo` MCP server the way this host exposes it: with pi-mcp-adapter, `mcp_connect` then the `mcp` proxy; with pi's built-in MCP, the `mcp__paseo__*` tools, found through `tool_search` when they are deferred. Load only the tools you call, never all 63 schemas. E17 records which route works.
2. Optional workspace: `paseo_create_workspace` (worktree, branch, or PR checkout).
3. Create the agent with a pinned model:

```jsonc
{
  "title": "Review auth diff",
  "provider": "pi/amazon-bedrock/global.anthropic.claude-sonnet-5-5",   // SKILL.md verb table
  "settings": { "thinkingOptionId": "medium" },
  "initialPrompt": "<brief, same shape as SKILL.md section 5, without the output field>",
  "labels": { "async-agents.verb": "sonnet", "async-agents.run-key": "review-1" },
  "notifyOnFinish": true
}
```
4. `awt ref paseo:agent/<id>`, then yield.

The awt Paseo plugin gives the agent its own awt node under the parent, so the subagent preamble does not apply. The agent runs `awt resume` and writes its own `out.md`.

## Model pin status

The pin is derived from the tool schema (`provider` is a provider/model pair) and from `paseo_list_models` for `pi` (ids are `amazon-bedrock/<id>`). It has not been exercised yet; E17 settles it.
Fallback if the combined form is rejected: `provider: "pi"` plus a model in `settings`, then set the model after creation. Record whichever form works here.
