#!/usr/bin/env node
// List a Paseo agent's provider subagent rows and check them.
//   node e2e/paseo-subagents.mjs <parentAgentId> [--expect N] [--since ISO] [--json]
// Needs the Paseo CLI client from an extracted app.asar:
//   npx @electron/asar extract <Paseo.app>/Contents/Resources/app.asar /tmp/paseo-asar   (PASEO_ASAR_DIR overrides)
// Exit 1 when the row count differs from --expect, or a row's description first line is over 60
// characters or starts with RUN_KEY (the brief must open with a short title line).
import { pathToFileURL } from "node:url";

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const val = (n) => (args.includes(n) ? args[args.indexOf(n) + 1] : undefined);
const parent = args.find((a, i) => !a.startsWith("--") && args[i - 1] !== "--expect" && args[i - 1] !== "--since");
if (!parent) {
  console.error("usage: paseo-subagents.mjs <parentAgentId> [--expect N] [--json]");
  process.exit(2);
}
const asar = process.env.PASEO_ASAR_DIR ?? "/tmp/paseo-asar";
const host = process.env.PASEO_HOST ?? "localhost:6767";
const { connectToDaemon } = await import(
  pathToFileURL(`${asar}/node_modules/@getpaseo/cli/dist/utils/client.js`).href
);
const client = await connectToDaemon({ target: { kind: "endpoint", host } });
let out;
try {
  out = await client.listProviderSubagents(parent);
} finally {
  await client.close?.();
}
const since = val("--since");
const rows = (out.subagents ?? []).filter((r) => !since || r.createdAt >= since);
const problems = [];
const lines = rows.map((r) => {
  const first = (r.description ?? "").split("\n")[0];
  if (first.length > 60) problems.push(`${r.id}: description first line is ${first.length} chars`);
  if (/^RUN_KEY/.test(first)) problems.push(`${r.id}: description starts with RUN_KEY`);
  return { id: r.id, status: r.status, title: r.title, first: first.slice(0, 60), subtitle: r.subtitle ?? "-" };
});
const expect = val("--expect");
if (expect !== undefined && rows.length !== Number(expect)) {
  problems.push(`expected ${expect} rows, found ${rows.length}`);
}
if (flag("--json")) console.log(JSON.stringify({ rows: lines, problems }, null, 1));
else {
  for (const l of lines) console.log(`${l.status.padEnd(10)} ${String(l.title).padEnd(14)} ${l.first}  [${l.subtitle}]`);
  console.log(`${rows.length} row(s)`);
  for (const p of problems) console.error(`FAIL ${p}`);
}
process.exit(problems.length ? 1 : 0);
