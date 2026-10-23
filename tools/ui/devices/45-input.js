// ================================================================ DEVICES: button and touch map
// Turns a screen's intents (what select, tap, next, previous, menu and back do there) into the controls of
// one watch, flags any action a watch cannot reach, and draws the optional touch overlay.
const DevInput = (function () {
  const esc = s => String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  // rows: [{ctl, act, touch}] in reading order. i = intents, ind = the screen enables the action menu indicator.
  function controls(P, i, ind) {
    const rows = [], add = (ctl, act, touch) => { if (act && (!touch || P.inputDef.touch)) rows.push({ ctl, act, touch: !!touch }); };   // A0: no touch rows
    const nav = i.prev || i.next ? (i.prev || "nothing") + " / " + (i.next || "nothing") : null;
    add("START", i.select);
    if (P.five) { add("UP / DOWN", nav); add("hold UP", i.menu); }
    add("BACK", i.back);
    for (const [c, a] of i.extra || []) add(c, a);
    if (P.input === "B") add("hold BACK", i.menu);
    if (P.input === "C" && ind) add("Swipe left", i.menu, true);
    add("Tap", i.tap === "= START" ? i.select : i.tap, true);
    add("Swipe up / down", i.next || i.prev ? (i.next || "nothing") + " / " + (i.prev || "nothing") : null, true);
    add("Swipe right", i.back, true);
    return rows;
  }
  // Every action must survive buttons only (FR255, fēnix with touch off) and every two-button watch.
  function flags(P, i, ind) {
    const out = [];
    if (P.input === "C" && i.menu && !ind) out.push("Unreachable here: \"" + i.menu + "\" needs MENU, and this watch has none (enable the indicator).");
    if (!P.five && i.upDownOnly) out.push("Unreachable here: " + i.upDownOnly + " needs UP/DOWN.");
    if (P.input === "A" && i.touchOnly) out.push("Touch only: " + i.touchOnly + " is lost with touch off.");
    if (P.input === "A0" && i.touchOnly) out.push("Unreachable here: " + i.touchOnly + " needs touch, and this watch has none.");
    return out;
  }
  function legendHtml(P, i, ind) {
    const rows = controls(P, i, ind);
    if (!rows.length) return "";
    const touchNote = P.input === "A" && rows.some(r => r.touch) ? `<dd class="vh">Grey rows are touch: with touch off only the buttons above remain, and they reach everything.</dd>` : "";
    return `<dl class="keys">${rows.map(r => `<dt${r.touch ? ' class="touch"' : ""}>${esc(r.ctl)}</dt><dd${r.touch ? ' class="touch"' : ""}>${esc(r.act)}</dd>`).join("")}${touchNote}</dl>`;
  }
  function todayHtml(keys) {
    const e = Object.entries(keys || {});
    return e.length ? `<dl class="keys">${e.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join("")}</dl>` : "";
  }

  // Overlay in device px over the canvas: swipe arrows, back edge, tap meaning, action menu swipe.
  function overlaySvg(P, i, ind) {
    if (!P.inputDef.touch) return "";
    const w = P.w, h = P.h, f = Math.round(w / 22), st = `font-family="Barlow Semi Condensed, Arial Narrow, sans-serif" font-weight="700" font-size="${f}" fill="#fff" stroke="#000" stroke-width="${f / 5}" paint-order="stroke"`;
    const arrow = (x1, y1, x2, y2) => `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#ffd400" stroke-width="${w / 90}" marker-end="url(#ah-${P.id})"/>`;
    let s = `<defs><marker id="ah-${P.id}" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="4" markerHeight="4" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#ffd400"/></marker></defs>`;
    if (i.next || i.prev) { s += arrow(w * .8, h * .62, w * .8, h * .38) + arrow(w * .86, h * .38, w * .86, h * .62); s += `<text x="${w * .77}" y="${h * .5}" text-anchor="end" dominant-baseline="middle" ${st}>swipe</text>`; }
    if (i.back) { s += arrow(w * .06, h * .5, w * .2, h * .5); s += `<text x="${w * .13}" y="${h * .44}" text-anchor="middle" ${st}>back</text>`; }
    if (i.tap) { const t = (i.tap === "= START" ? i.select : i.tap) || ""; s += `<text x="${w / 2}" y="${h * .86}" text-anchor="middle" ${st}>tap: ${esc(t.length > 26 ? t.slice(0, 25) + "…" : t)}</text>`; }
    if (P.input === "C" && ind && P.dd && P.dd.actionMenuHint) { const [x, y, , hh] = P.dd.actionMenuHint; s += arrow(x - w * .02, y + hh / 2, x - w * .16, y + hh / 2); s += `<text x="${x - w * .1}" y="${y - f * .4}" text-anchor="middle" ${st}>menu</text>`; }
    return `<svg class="overlay" viewBox="0 0 ${w} ${h}" aria-hidden="true">${s}</svg>`;
  }

  return { controls, flags, legendHtml, todayHtml, overlaySvg };
})();
