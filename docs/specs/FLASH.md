# Spec: flash (Paseo parity, do now, about 10 minutes)

Goal: make the pi subagent rows in Paseo's "N subagents" list read like native Claude ones, using only changes on our side. Background and gap table: `/Users/tushar.pandey/src/paseo-pi-async-agents/docs/PASEO-PARITY.md`. Already shipped: D13 (single calls, not workflows).

## Scope
In: brief title line (D14), a parity check script, one live verification, docs.
Out (see DELEGATE.md): chaos and stress e2e, workflow guard, awt/pcg changes. Out (see FUTURE.md): anything needing a Paseo change.

## Implementation
- F1. Every brief's first line is a short imperative title, at most 60 characters, no `RUN_KEY`, no path (example: `Map auth flow in api-js`). `RUN_KEY: <key>` is line 2. Paseo uses the start of `description` (the whole task text) as the row's primary line.
  - Edit `/Users/tushar.pandey/src/paseo-pi-async-agents/skills/async-agents/SKILL.md` section 5 (brief contents) and the examples in `skills/async-agents/references/agents.md`.
  - Builtin agents get the preamble appended at the end of the brief (unchanged); the title still goes first.
- F2. `e2e/paseo-subagents.mjs <parentAgentId> [--expect N] [--json]`. Connects to the local daemon (`localhost:6767`) with the Paseo CLI client from `$PASEO_ASAR_DIR` (default `/tmp/paseo-asar`, extracted with `npx @electron/asar extract <Paseo.app>/Contents/Resources/app.asar /tmp/paseo-asar`), calls `listProviderSubagents`, prints one line per row (`status`, `title`, first line of `description` cut to 60 characters, `subtitle` or `-`). Exit 1 when the row count differs from `--expect`, or when any row's description first line is longer than 60 characters or starts with `RUN_KEY`.
  - Base it on `/tmp/q.mjs` (connect with `{ target: { kind: "endpoint", host: "localhost:6767" } }`).
- F3. Docs: add D14 to `docs/SPEC.md` section 2, a section 15 ledger entry, and update the "Path to equivalence" list in `docs/PASEO-PARITY.md` (item 2 done). Mention the script in `README.md`.

## E2E (cheap, real Bedrock)
| ID | Scenario | Pass |
|---|---|---|
| P1 | This session launches 2 single async `general-ro` children on Sonnet with titled briefs | `paseo-subagents.mjs <this agent id> --expect 2` exits 0; titles are the agent name; description first lines are the short titles |
| P2 | Same, one child fails validation (bad model id) | no row for the failed launch, or a row with status `failed`; script reports it |
| P3 | Script negative: pass a parent with no subagents and `--expect 1` | exit 1 |

Spend cap: about $0.10 in total.

## Done when
F1 to F3 are merged to master in a signed commit, P1 to P3 pass, and the ledger records the results.
