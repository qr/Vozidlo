// Fit check for the Night Panel design reference (tools/ui/poc/).
//
// Runs every NEW render and simulator state of docs/design/vozidlo-poc.html headless, in plain
// node with a stubbed canvas, and checks each text line and shape against the fēnix 7 Pro circle
// (r 130) and the style guide: text hidden by the curve, text closer than EDGE px (default 12) to
// the edge, text over text or over icons and chips, letters in a digits-only number font, text on
// a grey fill, retired colours, and a monochrome pass that may only use black and white.
// The OLD (1.0) screens are not checked: they are the record of what was wrong.
//
// Usage: node tools/ui/fitcheck.mjs [card-id-prefix | sim]     exit code 1 when anything fails
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";

const dir = path.join(path.dirname(new URL(import.meta.url).pathname), "poc");
const parts = ["10-core.js", "20-old.js", "30-new-home.js", "31-new-status.js", "32-new-other.js", "40-sim.js"];
const filter = process.argv[2] || "";

let styleLog = [];
const ctx = new Proxy({}, {
  get(t, k) {
    if (k === "measureText") return s => ({ width: String(s).length * 0.55 * (parseFloat(String(t.font || "").split(" ")[1]) || 10) });
    if (k in t) return t[k];
    return () => {};
  },
  set(t, k, v) { t[k] = v; if (k === "fillStyle" || k === "strokeStyle") styleLog.push(String(v).toUpperCase()); return true; }
});
const el = () => ({ getContext: () => ctx, style: {}, appendChild() {}, setAttribute() {}, addEventListener() {}, querySelector: () => el(), querySelectorAll: () => [], classList: { add() {}, remove() {}, toggle() {} }, dataset: {} });
const sandbox = {
  console, Math, JSON, Map, Set, Object, Array, String, Number, Error, Promise, parseFloat, parseInt, isNaN,
  localStorage: { getItem: () => null, setItem() {} },
  document: { createElement: el, getElementById: () => null, querySelector: () => null, querySelectorAll: () => [], addEventListener() {}, documentElement: { style: { setProperty() {} } }, body: { dataset: {} }, fonts: { load: () => Promise.resolve(), ready: Promise.resolve() } },
  location: { hash: "" }, setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, clearInterval() {}, requestAnimationFrame: () => 0,
  addEventListener() {}, navigator: {}, performance: { now: () => 0 }
};
sandbox.window = sandbox;
vm.createContext(sandbox);
const code = parts.map(p => fs.readFileSync(path.join(dir, p), "utf8")).join("\n") +
  "\n;globalThis.__api = { Dc, CARDS, SIM_VIEWS, OLD_SCREENS, FM, PX, BANNED, T, TB, Ui, calibrate };";
vm.runInContext(code, sandbox, { filename: "poc.js" });
const A = sandbox.__api;
A.calibrate();
// Only settled frames are checked: the simulator's list slide (Ui.slideShift) is switched off.
A.Ui.SLIDE_MS = 0;

const RULE = A.T.RULE.toUpperCase(), GREENS = ["#00FF00", "#00AA00"];
const fails = [];
function halfChord(dy) { return dy >= 130 ? 0 : Math.sqrt(130 * 130 - dy * dy); }

function check(label, draw, mono) {
  const events = []; styleLog = [];
  A.Dc.onDraw = e => events.push(e);
  const dc = new A.Dc(ctx, 260, 260); dc.mono = mono;
  try { draw(dc); } catch (e) { fails.push([label, "throws", String(e && e.message || e)]); A.Dc.onDraw = null; return; }
  A.Dc.onDraw = null;
  events.forEach((e, i) => e.i = i);
  const fills = events.filter(e => e.op === "fill");
  const covered = e => fills.some(f => f.i > e.i && f.left <= e.left + 1 && f.right >= e.right - 1 && f.top <= e.top + e.asc * 0.25 + 1 && f.bottom >= e.top + e.asc - 1);
  const texts = events.filter(e => e.op === "text" && e.text.trim() && !covered(e) && !(e.clip && (e.top + e.asc <= e.clip.y || e.top + e.asc * 0.25 >= e.clip.y + e.clip.h)));
  for (let x = 0; x < texts.length; x++) for (let y = x + 1; y < texts.length; y++) {
    const p = texts[x], q = texts[y];
    const vt = Math.max(p.top + p.asc * 0.25, q.top + q.asc * 0.25), vb = Math.min(p.top + p.asc + (p.h || 0), q.top + q.asc);
    // The number fonts hold digits and a few symbols, none below the baseline: their ink ends there.
    const ink = e => [e.top + e.asc * 0.2, /^num/.test(e.font) ? e.top + e.asc : e.bottom - (e.bottom - e.top - e.asc) * 0.3];
    const pb = ink(p), qb = ink(q);
    const vo = Math.min(pb[1], qb[1]) - Math.max(pb[0], qb[0]), ho = Math.min(p.right, q.right) - Math.max(p.left, q.left);
    if (vo > 2 && ho > 2) fails.push([label, "text-over-text", `"${p.text}" (${p.font} y${Math.round(p.top)}) x "${q.text}" (${q.font} y${Math.round(q.top)})`]);
  }
  for (const e of texts) {
    const bt = e.top + e.asc * 0.25, bb = e.top + e.asc;
    for (const f of fills) {
      if (f.i < e.i && f.left <= e.left + 1 && f.right >= e.right - 1 && f.top <= bt + 1 && f.bottom >= bb - 1) continue;   // its own background
      if (f.i > e.i && f.left <= e.left + 1 && f.right >= e.right - 1 && f.top <= bt + 1 && f.bottom >= bb - 1) continue;   // covered later (panel)
      const ho = Math.min(f.right, e.right) - Math.max(f.left, e.left), vo = Math.min(f.bottom, bb) - Math.max(f.top, bt);
      if (ho > 2 && vo > 2 && String(f.color).toUpperCase() !== String(e.color).toUpperCase() && (f.right - f.left) < 120) { fails.push([label, "text-over-shape", `"${e.text}" (${e.font} y${Math.round(e.top)}) x shape ${Math.round(f.left)},${Math.round(f.top)} ${Math.round(f.right - f.left)}x${Math.round(f.bottom - f.top)} ${f.color}`]); break; }
    }
    const bandTop = e.top + e.asc * 0.25, bandBot = e.top + e.asc;
    if (e.clip && (bandBot <= e.clip.y || bandTop >= e.clip.y + e.clip.h)) continue;    // clipped away on purpose
    const hc = halfChord(Math.max(Math.abs(bandTop - 130), Math.abs(bandBot - 130)));
    const hidden = Math.max(0, (130 - hc) - e.left) + Math.max(0, e.right - (130 + hc));
    const margin = Math.min(e.left - (130 - hc), (130 + hc) - e.right);
    if (hidden > 1) fails.push([label, "off-circle", `"${e.text}" ${e.font} y${Math.round(e.top)} w${Math.round(e.right - e.left)} hidden ${Math.round(hidden)}px`]);
    else if (margin < (process.env.EDGE ? +process.env.EDGE : 12)) fails.push([label, "edge-tight", `"${e.text}" ${e.font} y${Math.round(e.top)} margin ${Math.round(margin)}px`]);
    if (e.font.startsWith("num") && !A.Ui.isNumberGlyphs(e.text)) fails.push([label, "number-font", `"${e.text}"`]);
    const col = String(e.color).toUpperCase();
    if (A.BANNED.includes(col)) fails.push([label, "banned-colour", `${col} text "${e.text}"`]);
    if (GREENS.includes(col)) fails.push([label, "green-text", `"${e.text}"`]);
    for (const f of fills) {
      if (String(f.color).toUpperCase() !== RULE) continue;
      if ((f.right - f.left) * (f.bottom - f.top) < 80) continue;   // dots, thin rules
      if (f.left < e.right && f.right > e.left && f.top < bandBot && f.bottom > bandTop) { fails.push([label, "text-on-grey", `"${e.text}"`]); break; }
    }
  }
  for (const f of fills) if (A.BANNED.includes(String(f.color).toUpperCase())) fails.push([label, "banned-colour", `fill ${f.color}`]);
  if (mono) {
    const bad = [...new Set(styleLog.filter(s => s.startsWith("#") && s !== "#000000" && s !== "#FFFFFF"))].filter(s => s !== "#FF00FF");
    if (bad.length) fails.push([label, "mono-colour", bad.join(" ")]);
  }
}

let count = 0;
for (const card of A.CARDS) {
  if (filter && !card.id.startsWith(filter)) continue;
  (card.neu || []).forEach((v, i) => {
    if (v.fitcheck === false) return;
    const label = `${card.id}#${i}${v.label ? " (" + v.label + ")" : ""}`;
    check(label, v.draw, false); check(label + " mono", v.draw, true); count++;
  });
}
for (const [name, view] of Object.entries(A.SIM_VIEWS)) {
  if (filter && !("sim:" + name).startsWith(filter) && filter !== "sim") continue;
  if (!view.newDesign) continue;     // OLD sim views mirror OLD screens, not checked
  const KEYS = ["DOWN", "UP", "START", "MENU", "SWIPE_UP", "SWIPE_DOWN"];
  const seqs = [[]]; for (const k of KEYS) { seqs.push([k]); for (const k2 of KEYS) seqs.push([k, k2]); }
  for (const o of [{}, { variant: "a" }, { variant: "b" }, { d2: "merged" }, { d4: "menu" }, { d7: "dots" }]) for (const sq of seqs) {
    let st, ok = true; const lab = "sim:" + name + JSON.stringify(o) + (sq.length ? "+" + sq.join("+") : "");
    try { st = view.init(Object.assign({}, o)); for (const k of sq) { const r = view.key(k, st); if (r && typeof r === "object" && (r.push || r.pop || r.replace)) { ok = false; break; } } } catch (e) { fails.push([lab, "throws", String(e.message || e)]); continue; }
    if (!ok) continue;
    check(lab, dc => view.draw(dc, st), false); count++;
  }
}
const byKind = {};
for (const f of fails) byKind[f[1]] = (byKind[f[1]] || 0) + 1;
for (const f of fails) console.log(f.join(" | "));
console.log(`\nchecked ${count} renders; ${fails.length} problems` + (fails.length ? " " + JSON.stringify(byKind) : ""));
process.exit(fails.length ? 1 : 0);
