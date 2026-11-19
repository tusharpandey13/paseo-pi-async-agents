#!/usr/bin/env node
// List a Paseo agent's provider subagent rows and check them.
//   node e2e/paseo-subagents.mjs <parentAgentId> [--expect N] [--since ISO] [--json]
//        [--expect-counts failed=1,completed=4] [--order alpha,bravo] [--timeline]
//        [--settle SECS] [--watch SECS --expect-seq running,canceled,running,completed]
//   --expect-counts  rows per status must match exactly (statuses not listed must have 0)
//   --order          the first line of row i must contain word i (launch order)
//   --timeline       also fetch each row's timeline and report its item count
//   --settle SECS    first poll until --expect N (default 1) rows exist and none is running, 3 polls in a row (max SECS)
//   --watch SECS     poll every 500 ms for SECS (stops early once --expect N rows exist and none is running),
//                    record each row's status changes; --expect-seq "running,canceled|running,completed"
//                    (one comma list per row, rows joined with |) must match exactly
//   PASEO_HOST (default localhost:6767) selects the daemon.
// Needs the Paseo CLI client from an extracted app.asar:
//   npx @electron/asar extract <Paseo.app>/Contents/Resources/app.asar /tmp/paseo-asar   (PASEO_ASAR_DIR overrides)
// Exit 1 when the row count differs from --expect, or a row's description first line is over 60
// characters or starts with RUN_KEY (the brief must open with a short title line). Exit 2: usage.
// Exit 3: the Paseo client or daemon could not be reached (no rows were checked).
import { pathToFileURL } from "node:url";

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const val = (n) => (args.includes(n) ? args[args.indexOf(n) + 1] : undefined);
const VALUE_FLAGS = ["--expect", "--since", "--expect-counts", "--order", "--settle", "--watch", "--expect-seq"];
const parent = args.find((a, i) => !a.startsWith("--") && !VALUE_FLAGS.includes(args[i - 1]));
if (!parent) {
  console.error("usage: paseo-subagents.mjs <parentAgentId> [--expect N] [--since ISO] [--json] [--expect-counts s=n,..] [--order w,..] [--timeline] [--settle S] [--watch S --expect-seq s,..]");
  process.exit(2);
}
const asar = process.env.PASEO_ASAR_DIR ?? "/tmp/paseo-asar";
const host = process.env.PASEO_HOST ?? "localhost:6767";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let client, out, rows = [];
const seqs = new Map();
const since = val("--since");
const list = async () => {
  out = await client.listProviderSubagents(parent);
  return (out.subagents ?? []).filter((r) => !since || r.createdAt >= since);
};
try {
  const { connectToDaemon } = await import(
    pathToFileURL(`${asar}/node_modules/@getpaseo/cli/dist/utils/client.js`).href
  );
  client = await connectToDaemon({ target: { kind: "endpoint", host } });
  rows = await list();
  if (val("--settle")) {
    const end = Date.now() + Number(val("--settle")) * 1000;
    let quiet = 0;
    while (Date.now() < end && quiet < 3) {
      rows = await list();
      quiet = rows.length >= Number(val("--expect") ?? 1) && !rows.some((r) => r.status === "running") ? quiet + 1 : 0;
      if (quiet < 3) await sleep(1000);
    }
  }
  if (val("--watch")) {
    const end = Date.now() + Number(val("--watch")) * 1000;
    while (Date.now() < end) {
      rows = await list();
      for (const r of rows) {
        const q = seqs.get(r.id) ?? [];
        if (q[q.length - 1] !== r.status) q.push(r.status);
        seqs.set(r.id, q);
      }
      if (val("--expect") && rows.length >= Number(val("--expect")) && !rows.some((r) => r.status === "running")) break;
      await sleep(500);
    }
  }
  if (flag("--timeline")) {
    for (const r of rows) {
      try { { const t = await client.fetchProviderSubagentTimeline(parent, r.id, { limit: 1000 }); r.timelineItems = (t.rows ?? []).length; } }
      catch (e) { r.timelineItems = `error: ${e?.message ?? e}`; }
    }
  }
} catch (e) {
  console.error(`cannot reach Paseo (asar ${asar}, host ${host}): ${e?.message ?? e}`);
  process.exit(3);
} finally {
  await client?.close?.();
}
const problems = [];
const lines = rows.map((r) => {
  const first = (r.description ?? "").split("\n")[0];
  if (first.length > 60) problems.push(`${r.id}: description first line is ${first.length} chars`);
  if (/^RUN_KEY/.test(first)) problems.push(`${r.id}: description starts with RUN_KEY`);
  return { id: r.id, status: r.status, title: r.title, first: first.slice(0, 60), subtitle: r.subtitle ?? "-", runKey: (r.description ?? "").match(/^RUN_KEY:\s*(\S+)/m)?.[1], timelineItems: r.timelineItems };
});
const expect = val("--expect");
if (expect !== undefined && rows.length !== Number(expect)) {
  problems.push(`expected ${expect} rows, found ${rows.length}`);
}
const counts = {};
for (const r of rows) counts[r.status] = (counts[r.status] ?? 0) + 1;
if (val("--expect-counts")) {
  const want = Object.fromEntries(val("--expect-counts").split(",").map((kv) => kv.split("=")));
  for (const k of new Set([...Object.keys(want), ...Object.keys(counts)])) {
    if ((counts[k] ?? 0) !== Number(want[k] ?? 0)) problems.push(`status ${k}: expected ${want[k] ?? 0}, found ${counts[k] ?? 0}`);
  }
}
if (val("--order")) {
  const words = val("--order").split(",");
  const got = rows.map((r) => words.find((w) => (r.description ?? "").split("\n")[0].toLowerCase().includes(w)) ?? "?");
  if (got.join(",") !== words.join(",")) problems.push(`order: expected ${words.join(",")}, found ${got.join(",")}`);
}
const seq = [...seqs.values()].map((q) => q.join(",")).join("|");
if (val("--expect-seq") && seq !== val("--expect-seq")) {
  problems.push(`status sequence: expected ${val("--expect-seq")}, found ${seq || "(none)"}`);
}
if (val("--watch") && !flag("--json")) console.log(`status sequence per row: ${seq || "(none)"}`);
if (!flag("--json")) console.log(`counts: ${JSON.stringify(counts)}`);
if (flag("--json")) console.log(JSON.stringify({ rows: lines, counts, seq, problems }, null, 1));
else {
  for (const l of lines) console.log(`${l.status.padEnd(10)} ${String(l.title).padEnd(14)} ${l.first}  [${l.subtitle}]${l.timelineItems === undefined ? "" : ` timeline=${l.timelineItems}`}`);
  console.log(`${rows.length} row(s)`);
  for (const p of problems) console.error(`FAIL ${p}`);
}
process.exit(problems.length ? 1 : 0);
