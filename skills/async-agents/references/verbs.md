# Model verbs

This is the only place the verb-to-model mapping lives. Update it when new models ship. E19 catches stale ids.

| Verb | Model id (`subagent` `model`) | Paseo `provider` |
|---|---|---|
| sonnet (default) | `amazon-bedrock/global.anthropic.claude-sonnet-5-5` | `pi/amazon-bedrock/global.anthropic.claude-sonnet-5-5` |
| haiku | `amazon-bedrock/global.anthropic.claude-haiku-5-5` | `pi/amazon-bedrock/global.anthropic.claude-haiku-5-5` |
| opus | `amazon-bedrock/global.anthropic.claude-opus-5-5` | `pi/amazon-bedrock/global.anthropic.claude-opus-5-5` |

- Bedrock ids need an inference-profile prefix (`global.`, `us.`, ...). A bare `anthropic.claude-*` id fails with "on-demand throughput isn't supported".
- Optional thinking suffix, only when the user asks: `<id>:low|medium|high|xhigh`.
- Cost tier: haiku < sonnet < opus.
- Synonyms such as "cheap" or "best" are not mapped.

Dev and E2E machines without Bedrock keep these exact ids. `dev/models.mock.json` routes them to a stand-in model (see README).
