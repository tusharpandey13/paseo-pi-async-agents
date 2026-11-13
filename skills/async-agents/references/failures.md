# Failure playbook

| Symptom | Fix |
|---|---|
| `Unknown subagent model` | Use the full id from the SKILL.md verb table (never the bare verb), else `subagent({action:"models"})`. |
| `on-demand throughput isn't supported` | The id lacks the `global.` or `us.` prefix. |
| Extension or MCP tool missing in a child | Launch with `async:true`; foreground children never load ambient extensions. Use `general`. For a builtin, add the tool to `agentOverrides.<name>.tools`. |
| Foreground launch fails asking for `async: true` | The agent needs ambient MCP tools. Relaunch async. |
| Child lacks global rules | The agent sets `inheritGlobalContext: false`, or the settings fragment is not merged. |
| Child blocked by `permission-gate` or `protected-paths` | The child calls `contact_supervisor`. The parent runs the action itself or approves a narrower command. |
| Builtin override load error "Did you mean" | Typo in `agentOverrides`; fix the key in `settings.json`. |
| Output file missing | `output` was not passed, or was relative (relative paths land in run artifacts). Check the result's `savedOutputPath`. |
| Validation error before launch (unknown model, agent, or field) | Do not retry. Report it with the closest valid options from the error, and ask. |
| Worktree writer's edit missing after the run | Managed worktrees are removed at completion. Apply `worktree-diffs/step-*/task-*.patch` from the run dir, or have the writer commit on its branch. |
| Any other launch or runtime failure | Stop, report the exact error and run id, and retry the same call once. Do not switch to `pi -p`, `pi -ne` or another CLI without approval. |
