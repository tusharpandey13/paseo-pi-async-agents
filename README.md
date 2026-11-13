# paseo-pi-async-agents

Seamless async subagents in pi (`pi-subagents`) and Paseo on Amazon Bedrock Claude models.

- "subagent", "delegate", "parallelize" launches async children on Sonnet by default.
- An explicit verb (`sonnet`, `haiku`, `opus`) selects the model.
- Children get extension tools, the global context, and the cost-governor and work-record rules.
- Paseo agents are an explicit escalation path with a pinned model.

Design and E2E plan: [docs/SPEC.md](docs/SPEC.md).

## Install

Requires pi with `pi-subagents` (tested with 0.88.1) and pcg.

```sh
./install.sh                 # dry run: planned links and settings diff
./install.sh --apply         # link skill, prompts, agents; merge settings (backup kept); add AGENTS.md pointer
./install.sh --agent-dir DIR # target another pi agent dir (default $PI_CODING_AGENT_DIR or ~/.pi/agent)
```

## Develop without Bedrock

The model ids are Bedrock ids. On a machine without Bedrock, keep the ids and mock them:
`dev/models.mock.json` routes the three `amazon-bedrock/global.anthropic.claude-*-5-5` ids to `deepseek/deepseek-flash`.
It is merged only into an isolated agent dir (`install.sh --dev` refuses `~/.pi/agent`).

```sh
e2e/setup.sh                 # /tmp/ppaa-e2e/agent: pi-subagents + pcg + this repo (--dev), fixture AGENTS.md, scratch awt node
e2e/run.sh E1 "do this in a subagent: reply foo bar"
e2e/cases.sh                 # E2..E18 concurrently, logs in /tmp/ppaa-e2e/logs
e2e/inspect.sh               # child runs: agent, requested/actual model, exit, acceptance, cost
```
