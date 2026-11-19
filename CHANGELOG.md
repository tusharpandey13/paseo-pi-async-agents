# Changelog

## 0.1.0 (19-Nov-2026)

First release.

- `async-agents` skill, agents (`general`, `general-ro`), prompts and `install.sh` for pi with `pi-subagents` 0.88.1: "subagent", "delegate" and "parallelize" launch async children on Sonnet by default; `sonnet`, `haiku` and `opus` (also as `/haiku` etc.) pick the model.
- Briefs open with a short title line (Paseo shows it as the row label), then `RUN_KEY:` and `MODEL:`. Parallel children are single `subagent` calls so Paseo shows a row for each.
- awt child nodes (needs awt 0.4.0 or newer): each child gets its own node `$AWT_DIR/agents/<RUN_KEY>/` and writes `out.md` there; its records are signed `sub:<RUN_KEY>`. A parent claims each `RUN_KEY` with an atomic `mkdir`, so two parents launching at once never share a key.
- Paseo escalation path with a pinned model.
- Tests: `e2e/setup.sh` (isolated pi agent dir, Bedrock ids mocked to a cheap model), `e2e/cases.sh`, the chaos suite `e2e/chaos.sh` (own Paseo daemon), and `e2e/paseo-subagents.mjs` for Paseo row checks. Verification ledger in `docs/SPEC.md`; Paseo behaviour in `docs/PASEO-PARITY.md`.
