# paseo-pi-async-agents

Design for making async subagents seamless in pi (`pi-subagents`) and Paseo on Amazon Bedrock Claude models.

- "subagent", "delegate", "parallelize" launches async children on Sonnet by default.
- An explicit verb (`sonnet`, `haiku`, `opus`) selects the model.
- Children get extension tools, the global context, and the cost-governor and work-record rules.
- Paseo agents are an explicit escalation path with a pinned model.

Status: spec only. Nothing is built. See [docs/SPEC.md](docs/SPEC.md).
