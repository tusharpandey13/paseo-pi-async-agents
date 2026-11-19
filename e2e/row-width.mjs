// Measure how Paseo's web UI truncates the subagent rows of one parent (issue #5).
//   node e2e/row-width.mjs <daemonPort> <viewportWidth> [screenshot.png]
// Rows must have first lines "L040 word00 ...|END", "L060 ...", ... (lengths 40/60/80/100/120, ending in |END).
// Needs: playwright-core + a Chromium (PLAYWRIGHT_BROWSERS_PATH), the app's web build served on 127.0.0.1:8099
//   (python3 -m http.server 8099 --bind 127.0.0.1 --directory <Paseo.app>/Contents/Resources/app-dist),
//   and an ISOLATED daemon whose config.json has daemon.cors.allowedOrigins ["http://127.0.0.1:8099"].
// The parent's workspace must be the first "main" in the sidebar. Prints one JSON line per length.
import { chromium } from "playwright-core";
const [port, width, shot] = process.argv.slice(2);
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: Number(width), height: 900 } });
await p.addInitScript((l) => { globalThis.__PASEO_INITIAL_DAEMON_CONNECTION__ = { listen: l }; }, `127.0.0.1:${port}`);
await p.goto("http://127.0.0.1:8099/"); await p.waitForTimeout(6000);
await p.locator("text=main >> visible=true").first().click().catch(() => {});
await p.waitForTimeout(4000);
const pill = p.getByText("5 subagents").first();
await pill.click({ timeout: 8000 }); await p.waitForTimeout(2500);
if (shot) await p.screenshot({ path: shot });
const res = await p.evaluate(() => {
  const out = [];
  for (const n of [40, 60, 80, 100, 120]) {
    const tag = "L" + String(n).padStart(3, "0");
    const e = [...document.querySelectorAll("*")].find((x) => x.children.length === 0 && (x.textContent || "").startsWith(tag + " word") && getComputedStyle(x).display !== "none" && x.getBoundingClientRect().width > 0);
    if (!e) { out.push({ n, found: false }); continue; }
    const node = e.firstChild, box = e.getBoundingClientRect();
    const fits = (k) => { const r = document.createRange(); r.setStart(node, 0); r.setEnd(node, k); const rr = r.getBoundingClientRect(); return rr.right <= box.right + 0.5; };
    let lo = 0, hi = node.length; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (fits(m)) lo = m; else hi = m - 1; }
    // the ellipsis takes ~1em; visible chars before it = lo minus the chars displaced by the ellipsis
    const r2 = document.createRange(); r2.setStart(node, 0); r2.setEnd(node, lo);
    out.push({ n, rowWidthPx: Math.round(e.clientWidth), textChars: node.length, charsThatFitIncludingEllipsisRoom: lo, titleFullyVisible: lo - 1 >= n, ellipsis: getComputedStyle(e).textOverflow, shown: node.textContent.slice(0, Math.max(0, lo - 1)) });
  }
  return out;
});
for (const r of res) console.log(JSON.stringify(r));
await b.close();
