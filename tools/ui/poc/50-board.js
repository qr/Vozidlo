// ================================================================ Board (agent E)
// Builds the OLD | NEW rows from SECTION_ORDER, SECTION_META, OLD_SCREENS and CARDS, and wires the toolbar.
// Exposes window.Board {build, renderWatch, wire, sync, save} plus window.build / window.renderWatch.
(function () {
  const OPT_KEY = "vozidlo-poc-opt";
  const esc = s => String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  // Card text from the parts may carry simple inline HTML (<em>, <code>); keep it, line breaks become spaces.
  const txt = s => String(s == null ? "" : s).replace(/\n/g, " ");

  function countError(e) {
    window.__jsErrors = (window.__jsErrors || 0) + 1;
    if (document.body) document.body.dataset.jsErrors = window.__jsErrors;
    console.error(e);
  }

  // One watch: bezel SVG + 260 × 260 canvas. Sizes are relative to the figure, so the watch
  // shrinks with its column on narrow screens while the canvas keeps 260 internal pixels.
  function renderWatch(draw, o = {}) {
    const d = 260 * OPT.scale, ring = d * 0.14, size = OPT.bezel ? d + ring * 2 : d;
    const fig = document.createElement("div"); fig.className = "watch" + (OPT.bezel ? "" : " flat");
    fig.style.width = size + "px";
    if (OPT.bezel) fig.innerHTML = bezelSvg(d);
    const cv = document.createElement("canvas"); cv.width = 260; cv.height = 260;
    if (OPT.bezel) { const p = (ring / size * 100) + "%", w = (d / size * 100) + "%"; cv.style.left = cv.style.top = p; cv.style.width = cv.style.height = w; }
    cv.setAttribute("role", "img"); cv.setAttribute("aria-label", (o.label || "Watch screen") + ", 260 by 260 round screen");
    const dc = new Dc(cv.getContext("2d"), 260, 260); dc.mono = !!o.mono;
    try { draw(dc); }
    catch (e) {
      countError(e);
      try { dc.clearClip(); } catch (e2) {}
      dc.mono = false; dc.setColor("#FF0000", "#300000"); dc.clear();
      dc.setColor("#FFFFFF"); dc.drawText(130, 112, "small", "Draw error", J.CENTER);
      dc.drawText(130, 146, "xtiny", String(e && e.message || e).slice(0, 28), J.CENTER);
    }
    if (OPT.guides) guides(dc);
    fig.appendChild(cv); return fig;
  }

  function placeholder(title, sub) {
    const d = 260 * OPT.scale, size = OPT.bezel ? d * 1.28 : d;
    const el = document.createElement("div"); el.className = "watch none"; el.style.width = size + "px";
    el.innerHTML = `<div>${esc(title)}${sub ? `<small>${esc(sub)}</small>` : ""}</div>`;
    return el;
  }

  const tagHtml = tags => (tags || []).filter(t => typeof TAGS !== "undefined" && TAGS[t])
    .map(t => `<span class="tag ${TAGS[t][0]}">${TAGS[t][1]}</span>`).join("");
  const keysHtml = keys => Object.entries(keys || {}).map(([k, v]) => `<dt>${esc(k)}</dt><dd>${txt(v)}</dd>`).join("");
  const notesHtml = notes => (notes || []).map(n => typeof n === "string" ? `<li>${txt(n)}</li>` : n && n.flag ? `<li class="flag">${txt(n.flag)}</li>` : "").join("");

  // Merge OLD_SCREENS and CARDS by id, grouped per section and sorted by order.
  function collect() {
    const byId = new Map();
    for (const id in OLD_SCREENS) byId.set(id, { id, old: OLD_SCREENS[id], card: null });
    for (const c of CARDS) {
      if (!c || !c.id) continue;
      const e = byId.get(c.id) || { id: c.id, old: null, card: null };
      e.card = c; byId.set(c.id, e);
    }
    const sections = new Map();
    let seq = 0;
    for (const e of byId.values()) {
      e.section = (e.card && e.card.section) || (e.old && e.old.section) || "other";
      e.order = e.old && e.old.order != null ? e.old.order : e.card && e.card.order != null ? e.card.order : 1e6;
      e.seq = seq++;
      if (!sections.has(e.section)) sections.set(e.section, []);
      sections.get(e.section).push(e);
    }
    for (const list of sections.values()) list.sort((a, b) => a.order - b.order || a.seq - b.seq);
    const order = SECTION_ORDER.slice();
    for (const s of sections.keys()) if (!order.includes(s)) order.push(s);
    return order.map(id => ({ id, meta: SECTION_META[id] || { title: id }, entries: sections.get(id) || [] }));
  }

  function renderEntry(e) {
    const { old, card } = e, vars = (card && card.neu) || [];
    const name = (card && card.name) || (old && old.name) || e.id;
    const el = document.createElement("article"); el.className = "card"; el.id = e.id;
    el.innerHTML = `<h3><a href="#${esc(e.id)}">${esc(name)}</a><span class="id">${esc(e.id)}</span></h3>`;

    // .pair = Today figure + .neus (the proposal variants wrap among themselves, right of Today).
    const pair = document.createElement("div"); pair.className = "pair";
    const neus = document.createElement("div"); neus.className = "neus";
    neus.style.minWidth = `min(100%, ${Math.ceil(260 * OPT.scale * (OPT.bezel ? 1.28 : 1))}px)`;
    const fig = (cls, cap, watch, src) => {
      const f = document.createElement("figure"); f.className = cls;
      f.innerHTML = `<figcaption>${cap}</figcaption>`;
      f.appendChild(watch);
      if (src) f.insertAdjacentHTML("beforeend", `<div class="src">${esc(src)}</div>`);
      (cls === "old" ? pair : neus).appendChild(f);
    };
    if (old) fig("old", `<span class="who">Today</span>${tagHtml(old.tags)}`, renderWatch(old.draw, { label: name + ", today" }), old.src);
    else fig("old", `<span class="who">Today</span>`, placeholder("New state", "No screen for this today."));
    if (vars.length) {
      vars.forEach(v => {
        const cap = `<span class="who">Proposal</span>` + (v.label ? `<span class="vl">${esc(v.label)}</span>` : "") +
          (v.decision ? `<span class="dec" title="Open decision ${esc(v.decision)}">${esc(v.decision)}</span>` : "") + tagHtml(v.tags);
        fig("neu", cap, renderWatch(v.draw, { mono: OPT.mono, label: name + (v.label ? ", " + v.label : "") + ", proposal" }));
      });
    } else {
      fig("neu", `<span class="who">Proposal</span>`, placeholder("No change proposed", card ? "" : "Same screen in the new look, or not part of this proposal."));
    }
    pair.appendChild(neus); el.appendChild(pair);

    // Info: what changed + fix ids | keys | notes
    const cols = [];
    const changed = (card && card.changed) || [], fixes = (card && card.fixes) || [];
    if (changed.length || fixes.length) {
      cols.push(`<div><h4>What changed</h4>${changed.length ? `<ul>${changed.map(c => `<li>${txt(c)}</li>`).join("")}</ul>` : ""}` +
        (fixes.length ? `<div class="fixes" aria-label="Fix ids">${fixes.map(f => `<span class="fix">${esc(f)}</span>`).join("")}</div>` : "") + `</div>`);
    }
    const oldKeys = old ? keysHtml(old.keys) : "";
    let newKeys = "";
    const withKeys = vars.filter(v => v.keys && Object.keys(v.keys).length);
    const sameKeys = withKeys.length > 1 && withKeys.every(v => JSON.stringify(v.keys) === JSON.stringify(withKeys[0].keys));
    if (withKeys.length === 1 || sameKeys) newKeys = keysHtml(withKeys[0].keys);
    else withKeys.forEach(v => { newKeys += `<div class="vh">${esc(v.label || "Variant")}</div>` + keysHtml(v.keys); });
    if (oldKeys || newKeys) {
      cols.push(`<div>` + (oldKeys ? `<h4>Keys today</h4><dl class="keys">${oldKeys}</dl>` : "") +
        (newKeys ? `<h4>Keys in the proposal</h4><dl class="keys">${newKeys}</dl>` : "") + `</div>`);
    }
    const oldNotes = old ? notesHtml(old.notes) : "", newNotes = card ? notesHtml(card.notes) : "";
    if (oldNotes || newNotes) {
      cols.push(`<div>` + (oldNotes ? `<h4>Notes on today</h4><ul class="notes">${oldNotes}</ul>` : "") +
        (newNotes ? `<h4>Notes on the proposal</h4><ul class="notes">${newNotes}</ul>` : "") + `</div>`);
    }
    if (cols.length) el.insertAdjacentHTML("beforeend", `<div class="info">${cols.join("")}</div>`);
    return el;
  }

  function build() {
    const board = document.getElementById("board"); if (!board) return;
    board.innerHTML = "";
    for (const sec of collect()) {
      const m = sec.meta;
      const el = document.createElement("section"); el.className = "area"; el.id = sec.id;
      el.setAttribute("aria-labelledby", "h-" + sec.id);
      el.innerHTML = `<h2 id="h-${esc(sec.id)}">${esc(m.title || sec.id)}${m.src ? ` <small>${esc(m.src)}</small>` : ""}</h2>` +
        (m.blurb ? `<p>${txt(m.blurb)}</p>` : "") + (m.neu ? `<p class="neu">${txt(m.neu)}</p>` : "");
      if (!sec.entries.length) el.insertAdjacentHTML("beforeend", `<p class="empty">No screens in this section yet.</p>`);
      const list = document.createElement("div"); list.className = "cards";
      for (const e of sec.entries) {
        try { list.appendChild(renderEntry(e)); } catch (err) { countError(err); }
      }
      el.appendChild(list); board.appendChild(el);
    }
  }

  function save() { try { localStorage.setItem(OPT_KEY, JSON.stringify(OPT)); } catch (e) {} }
  function sync() {
    document.querySelectorAll("[data-scale]").forEach(b => b.setAttribute("aria-pressed", String(+b.dataset.scale === +OPT.scale)));
    document.querySelectorAll("input[data-opt]").forEach(i => { i.checked = !!OPT[i.dataset.opt]; });
  }
  // Rebuild the board on a toolbar change; the simulator stays mounted (it may offer SIM.refresh()).
  function changed() {
    save(); sync();
    try { build(); } catch (e) { countError(e); }
    try { if (window.SIM && typeof SIM.refresh === "function") SIM.refresh(); } catch (e) { countError(e); }
    document.body.dataset.jsErrors = window.__jsErrors || 0;
  }
  function wire() {
    if (![1, 1.5, 2].includes(+OPT.scale)) OPT.scale = 1;
    document.querySelectorAll("[data-scale]").forEach(b => b.addEventListener("click", () => { OPT.scale = +b.dataset.scale; changed(); }));
    document.querySelectorAll("input[data-opt]").forEach(i => i.addEventListener("change", () => { OPT[i.dataset.opt] = i.checked; changed(); }));
    sync();
    // Keep anchors clear of the sticky toolbar.
    const tb = document.getElementById("toolbar");
    const setH = () => document.documentElement.style.setProperty("--tb-h", (tb ? tb.offsetHeight : 64) + "px");
    setH();
    if (tb && window.ResizeObserver) new ResizeObserver(setH).observe(tb);
  }

  window.Board = { build, renderWatch, wire, sync, save };
  window.build = build; window.renderWatch = renderWatch;
})();
