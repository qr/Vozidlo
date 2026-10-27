// ================================================================ DEVICES: board
// Device table, input profiles, then one card per screen with a watch per column. Watches render when
// they scroll into view (?all=1 renders everything at once, for tools/ui/devices/shoot.sh).
const DevBoard = (function () {
  const KEY = "vozidlo-devices-opt2";
  const DOPT = { scale: 1, size: "mm", overlay: false, mono: false, fontScale: false, cols: {} };
  try { const s = JSON.parse(localStorage.getItem(KEY) || "null"); if (s) Object.assign(DOPT, s); } catch (e) {}
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(DOPT)); } catch (e) {} };
  const esc = s => String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const ALL = /[?&]all=1/.test(location.search);   // ?all=1: every column, all drawn at once (shoot.sh, review)
  const ONLY = (location.search.match(/[?&]only=([a-z]+)/) || [])[1];   // ?only=status: one section, for review
  const SECTIONS = {
    entry: ["Entry", "ui/GlanceView.mc", "The glance in the watch's glance list. Drawn at device pixels: the content area comes from each device file."],
    home: ["Home", "ui/HomeMenu.mc · ui/HomeHero.mc", "A CustomMenu with the hero in its title area. Rows, pill and hero are laid out from the Dc and the device fonts. Every command asks first, on a NightMenu confirmation (US-062)."],
    status: ["Status", "ui/StatusPages.mc · ui/StatusPager.mc", "The status loop. Positions stack from measured font heights instead of the 260 px constants."],
    charging: ["Charging", "ui/ChargingDetailView.mc · ui/ChargingLimitMenu.mc · ui/ChargingProfilesView.mc", "Charging detail with its list, the charge limit and mode lists, and the profiles."],
    findcar: ["Find my car", "ui/LocationView.mc · ui/MapPreviewView.mc", "START opens the map where the watch has MapView and the car is parked; otherwise the Find my car list (M4)."],
    settings: ["Settings", "ui/screens/SettingsScreen.mc · ui/TemperatureMenu.mc · ui/TileOrderView.mc", "Home's Settings row opens a list with the tile order, Confirmation (asking before commands) and Clear stored data. The target temperature becomes a list on every watch (M6); tile order is already a list."],
    onboarding: ["Onboarding", "ui/OnboardingView.mc · ui/OnboardingDelegate.mc", "Text screens before a key is set up. The MENU route moves with the watch: hold UP, hold BACK, or the action menu indicator."],
    garmin: ["Garmin UI", "native", "Garmin draws these itself. On the AMOLED watches they are stand-ins, from the areas the device files give."]
  };
  const ORDER = ["entry", "home", "status", "charging", "findcar", "settings", "onboarding", "garmin"];
  const colOn = id => ALL || (id in DOPT.cols ? DOPT.cols[id] : DEV.DEFAULT_ON.includes(id));
  let profiles = {}, outcomes = {};
  let io = null;

  function countError(e) { window.__jsErrors = (window.__jsErrors || 0) + 1; if (document.body) document.body.dataset.jsErrors = window.__jsErrors; console.error(e); }
  function opts(extra) { return Object.assign({ mono: DOPT.mono, size: DOPT.size, scale: DOPT.scale }, extra); }
  function sizeOf(P) {
    const cssW = (DOPT.size === "px" ? P.w * 0.62 : P.mm * DevRender.MM) * DOPT.scale;
    return P.shape === "rect" ? [cssW * 1.18, cssW * 1.18 * (P.h / P.w + 0.15)] : [cssW * (P.five ? 1.28 : 1.2), cssW * (P.five ? 1.28 : 1.2)];
  }
  function placeholder(P, title, sub) {
    const [w] = sizeOf(P), el = document.createElement("div");
    el.className = "watch none"; el.style.width = w + "px";
    el.innerHTML = `<div>${esc(title)}${sub ? `<small>${esc(sub)}</small>` : ""}</div>`;
    return el;
  }
  function withOverlay(fig, P, i, ind) {
    const svg = DevInput.overlaySvg(P, i, ind); if (!svg) return fig;
    const cv = fig.querySelector("canvas"); fig.insertAdjacentHTML("beforeend", svg);
    const ov = fig.querySelector("svg.overlay"); ["left", "top", "width", "height"].forEach(k => { ov.style[k] = cv.style[k]; });
    return fig;
  }

  // ------------------------------------------------------------ one column of one screen
  function watchFor(scr, col) {
    const P = profiles[col];
    if (P.today) {
      if (!scr.today) return placeholder(P, "New", "not in the app today");
      return DevRender.renderDevice(P, (dc, G) => scr.today(dc, G, P), opts({ glyphMap: scr.todayGlyphMap, label: scr.name + ", today" }));
    }
    if (!scr.avail(P)) return placeholder(P, "n/a", scr.id.startsWith("fc-map") ? "no MapView on this watch" : "not on this watch");
    const ind = !!scr.indicator && P.input === "C";
    const fig = DevRender.renderDevice(P, (dc, G) => { scr.prop(dc, G, P); if (ind && !scr.raw) G.indicator(dc); },
      opts({ raw: !!scr.raw && P.id !== "fenix7pro", indicator: ind, bg: scr.bg, glyphMap: scr.glyphMap, label: scr.name }));
    return DOPT.overlay ? withOverlay(fig, P, scr.intents(P), ind) : fig;
  }
  function badge(scr, P) {
    if (P.today) return scr.today ? ["as built", "same"] : ["new", "adapted"];
    if (!scr.avail(P)) return ["n/a", "na"];
    if (P.id === "fenix7pro") return scr.newOnly ? ["new", "adapted"] : scr.fenix === "same" ? ["unchanged", "same"] : ["changed", "adapted"];
    return scr.kind === "scaled" ? ["scaled", "scaled"] : ["adapted", "adapted"];
  }
  function notesFor(scr, P) {
    const n = scr.notes || {};
    if (P.today) return n.today || [];
    if (!scr.avail(P)) return [];
    const by = [P.input].concat(P.shape === "rect" ? ["X1"] : [], [P.id], P.map ? [] : ["noMap"]);
    return [].concat(...by.map(k => n[k] || []));   // notes.all is shown once per card
  }
  const notesHtml = list => list.length ? `<ul class="notes">${list.map(x => typeof x === "string" ? `<li>${esc(x)}</li>` : `<li class="flag">${esc(x.flag)}</li>`).join("")}</ul>` : "";

  function figure(scr, col) {
    const P = profiles[col], [b, cls] = badge(scr, P);
    const fig = document.createElement("figure"); fig.className = "col" + (P.today ? " old" : "");
    const ind = !!scr.indicator && P.input === "C";
    const i = P.today || !scr.avail(P) ? null : scr.intents(P);
    const legend = P.today ? DevInput.todayHtml(scr.todayKeys) : i ? DevInput.legendHtml(P, i, ind) : "";
    const flags = i ? DevInput.flags(P, i, ind).map(f => ({ flag: f })) : [];
    fig.innerHTML = `<figcaption><span class="who">${esc(P.name)}</span><span class="badge ${cls}">${esc(b)}</span><span class="sub">${esc(P.sub)}</span></figcaption>
      <div class="slot"></div>${legend}${notesHtml(flags.concat(notesFor(scr, P)))}`;
    const slot = fig.querySelector(".slot"), [w, h] = sizeOf(P);
    slot.style.minWidth = w + "px"; slot.style.minHeight = h + "px";
    slot._draw = () => { try { slot.replaceChildren(watchFor(scr, col)); slot.style.minHeight = ""; } catch (e) { countError(e); } };
    if (ALL || !io) slot._draw(); else io.observe(slot);
    return fig;
  }

  // ------------------------------------------------------------ layout outcomes
  // Drawn on a scratch canvas with each column's own watch: what differs per watch (hero font, chips kept, lock grid,
  // onboarding texts cut with "…"). The watch table shows them, and the page's copy is filled from them instead of listing watches.
  function outcomeOf(P) {
    const SCR = DEV_SCREENS.DS;
    // Status and onboarding turn Garmin's action menu indicator on where there is no MENU key, and its keep-out
    // narrows the right edge there, as on their cards; home has no indicator.
    const ind = { indicator: P.input === "C" };
    return Object.assign(DevRender.probe(P, (dc, G) => ({ hero: G.heroFont, home: SCR.home(dc, G, {}) })),
      DevRender.probe(P, (dc, G) => ({ status: SCR.status(dc, G, { page: "lock" }),
        cut: ["guide", "check", "expiry", "expired"].filter(t => SCR.obText(dc, G, NO.TEXT[t], { glyphs: true }).cut) }), ind));
  }

  // ------------------------------------------------------------ copy that names watches
  // <span data-fill="key[:arg]"> in 00-head.html: filled from DEV_DATA and the layout outcomes, so the prose follows the
  // manifest. Products are named by DEV.shortName, columns by their name.
  function fill() {
    const cols = DEV.COLUMNS.filter(c => c !== "today").map(c => profiles[c]), data = Object.values(DEV_DATA);
    const screens = [...new Set(data.slice().sort((a, b) => (a.shape === "rectangle") - (b.shape === "rectangle") || a.w - b.w)
      .map(d => d.w + (d.shape === "rectangle" ? " × " + d.h : "")))];
    const F = {
      count: () => String(data.length),
      columns: () => String(cols.length),
      screens: () => DEV.list(screens),
      icons: () => DEV.list([...new Set(data.map(d => d.launcher))].sort((a, b) => a - b).map(String)),
      profile: a => DEV.list(DEV.namesWhere(d => d.profile === a)),
      map: a => DEV.list(DEV.namesWhere(d => d.mapView === (a === "yes"))),
      hero: a => DEV.list(cols.filter(P => outcomes[P.id].hero === a).map(P => P.name)) || "none"
    };
    document.querySelectorAll("[data-fill]").forEach(el => {
      const [k, a] = el.dataset.fill.split(":");
      try { el.textContent = F[k](a); } catch (e) { countError(new Error("data-fill " + el.dataset.fill + ": " + e.message)); }
    });
  }

  // ------------------------------------------------------------ static parts
  function devicesTable() {
    const ids = DEV.COLUMNS.filter(c => c !== "today"), rows = ids.map(id => profiles[id]);
    const cell = f => rows.map(P => `<td>${f(P)}</td>`).join("");
    const fh = (P, k) => P.fm ? Math.round(P.fm[k].h * P.s) : FM[k].h;
    const kb = n => n == null ? "n/a" : Math.round(n / 1024) + " KB";
    const covered = P => P.covers.map(p => esc(DEV_DATA[p].name.replace(/®|™/g, ""))).join("<br>");
    const out = outcomes;
    const chips = P => { const h = out[P.id].home; return h.chips === 2 ? "both" : h.chips === 1 ? "<b>Locked only</b>" : "<b>none</b>"; };
    const grid = P => { const L = out[P.id].status.lock; return L.rows + " rows" + (L.step ? ", squeezed (step " + L.step + ")" : "") + (L.more ? ", <b>+N</b>" : "") + (L.word !== "medium" ? ", word in small" : ""); };
    const cut = P => out[P.id].cut.length ? "<b>" + out[P.id].cut.map(esc).join(", ") + "</b>" : "none";
    return `<table class="facts"><thead><tr><th></th>${rows.map(P => `<th>${esc(P.name)}</th>`).join("")}</tr></thead><tbody>
      <tr><th>Products covered</th>${cell(covered)}</tr>
      <tr><th>Display</th>${cell(P => `${P.w} × ${P.h} ${P.shape === "rect" ? "rectangle" : "round"}`)}</tr>
      <tr><th>Panel</th>${cell(P => esc(P.panel) + " · " + (P.ppi ? P.ppi + " ppi" : "ppi n/a"))}</tr>
      <tr><th>Width</th>${cell(P => P.mm.toFixed(1) + " mm" + (P.ppi ? "" : " *"))}</tr>
      <tr><th>Input</th>${cell(P => esc(P.input + ": " + P.inputDef.name))}</tr>
      <tr><th>Touch</th>${cell(P => P.touch ? "yes" : "<b>no</b>")}</tr>
      <tr><th>MapView</th>${cell(P => P.map ? "yes" : "<b>no</b>")}</tr>
      <tr><th>Watch-app budget</th>${cell(P => [...new Set(P.covers.map(p => kb(DEV_DATA[p].budget.watchApp)))].join(" / "))}</tr>
      <tr><th>s = w / 260</th>${cell(P => P.s.toFixed(3))}</tr>
      <tr><th>Fonts</th>${cell(P => esc(P.fonts))}</tr>
      <tr><th>Heights xtiny · tiny · small · medium</th>${cell(P => ["xtiny", "tiny", "small", "medium"].map(k => fh(P, k)).join(" · "))}</tr>
      <tr><th>Heights numMild · numMed</th>${cell(P => ["numMild", "numMed"].map(k => fh(P, k)).join(" · "))}</tr>
      <tr><th>Hero number font (M1)</th>${cell(P => out[P.id].hero === "numMed" ? "NUMBER_MEDIUM" : "NUMBER_MILD")}</tr>
      <tr><th>Row height</th>${cell(P => Math.round(P.rowH * P.s) + " px")}</tr>
      <tr><th>Home chips (Locked, plug)</th>${cell(chips)}</tr>
      <tr><th>Lock grid (M12), 6 items</th>${cell(grid)}</tr>
      <tr><th>Onboarding text cut with … (M14)</th>${cell(cut)}</tr>
      <tr><th>Glance area</th>${cell(P => P.glance ? P.glance[2] + " × " + P.glance[3] : "n/a")}</tr>
      <tr><th>Launcher icon</th>${cell(P => P.launcher + " px")}</tr>
      </tbody></table>
      <p class="fine">${Object.keys(DEV_DATA).length} products in ${rows.length} columns. Products share a column when they share screen family, input profile, MapView and font technology (bitmap or TrueType): close enough to share one design. A column is drawn as its product that the unit tests run on (<code>VERIFY_DEVICES</code> in <code>tools/ciq</code>), else its first in the manifest; the columns, and which are shown by default, are generated with the device facts. Fonts within a column can still differ slightly, so every product is checked on its own by <code>tools/ui/fitcheck.mjs --devices</code>; the last three rows are what the column's own watch gives. From each watch's compiler.json, simulator.json and api.debug.xml (SDK ${esc(DEV_META.sdk)}), generated into <code>tools/ui/devices/11-devdata.js</code> by <code>devdata.py</code>.${rows.some(P => !P.ppi) ? ` * No ppi in the device file; the width uses the ppi of a watch with the same screen (${rows.filter(P => !P.ppi).map(P => esc(P.name) + ": " + DEV.ppiFor(P.dd)).join(", ")}).` : ""}${rows.some(P => P.shape === "rect") ? ` The rectangle's display corner radius (${DEV.X1_CORNER} px) is estimated from the simulator artwork.` : ""}</p>`;
  }
  // One figure per input profile, drawn as the first column with that profile; the watches named are every product
  // with it (A0 also stands for an A watch with touch switched off).
  function profilesSection() {
    const items = Object.keys(DEV.INPUT).map(key => [key, DEV.COLUMNS.find(c => c !== "today" && DEV.BASE[c].input === key), !DEV.INPUT[key].touch]).filter(([, col]) => col);
    return items.map(([key, col, off]) => {
      const I = DEV.INPUT[key], P = profiles[col];
      const rows = [["START", "select"], ["BACK", "back"], ...(I.next.length ? [["UP / DOWN", "previous / next"]] : []), ...(I.menu.length ? [[I.menu[0], "menu"]] : []),
        ...(I.actionMenu ? [[I.actionMenu, "menu (onActionMenu)"]] : []), ...(I.touch ? [["Tap", "select"], ["Swipe up / down", "next / previous"], ["Swipe right", "back"]] : [])];
      return `<figure class="prof" data-col="${col}" data-off="${off ? 1 : 0}"><figcaption><span class="dec">${key}</span> <b>${esc(I.name)}</b><br><span class="sub">${esc(DEV.list(DEV.namesWhere(d => d.profile === key), 5) + (key === "A0" ? ", or any A watch with touch off" : ""))}</span></figcaption>
        <div class="slot"></div><dl class="keys">${rows.map(([c, a]) => `<dt>${esc(c)}</dt><dd>${esc(a)}</dd>`).join("")}</dl></figure>`;
    }).join("");
  }

  // ------------------------------------------------------------ build
  function build() {
    profiles = {}; for (const c of DEV.COLUMNS) profiles[c] = DEV.derive(c, { fontScale: DOPT.fontScale ? 1.4 : 1 });
    outcomes = {}; for (const c of DEV.COLUMNS) if (!profiles[c].today) { try { outcomes[c] = outcomeOf(profiles[c]); } catch (e) { countError(e); } }
    fill();
    if (io) io.disconnect();
    io = ALL || !("IntersectionObserver" in window) ? null : new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { io.unobserve(e.target); e.target._draw(); } }), { rootMargin: "600px 0px" });
    document.getElementById("facts").innerHTML = devicesTable();
    const pr = document.getElementById("profiles-grid"); pr.innerHTML = profilesSection();
    pr.querySelectorAll("figure.prof").forEach(f => {
      const P = profiles[f.dataset.col], slot = f.querySelector(".slot");
      try {
        const fig = DevRender.renderDevice(P, (dc, G) => DEV_SCREENS.DS.home(dc, G, {}), opts({ label: "Home" }));
        if (f.dataset.off === "1") fig.insertAdjacentHTML("beforeend", `<span class="touchoff">no touch</span>`);
        slot.replaceChildren(fig);
      } catch (e) { countError(e); }
    });
    const board = document.getElementById("board"); board.replaceChildren();
    for (const sec of ORDER) {
      if (ONLY && sec !== ONLY) continue;
      const list = DEV_SCREENS.list.filter(s => s.section === sec); if (!list.length) continue;
      const [title, src, blurb] = SECTIONS[sec], el = document.createElement("section");
      el.className = "area"; el.id = sec;
      el.innerHTML = `<h2>${esc(title)} <small>${esc(src)}</small></h2><p>${esc(blurb)}</p><div class="cards"></div>`;
      const cards = el.querySelector(".cards");
      for (const scr of list) {
        const card = document.createElement("article"); card.className = "card"; card.id = scr.id;
        const tags = (scr.tags || []).map(t => `<span class="tag ${t}">${t === "sys" ? "Garmin UI, approx." : "Example data"}</span>`).join("");
        const shared = (scr.notes && scr.notes.all) || [];
        card.innerHTML = `<h3><a href="#${scr.id}">${esc(scr.name)}</a><span class="id">${scr.id}</span>${tags}<span class="src">${esc(scr.src)}</span></h3><div class="row"></div>` +
          (shared.length ? `<div class="shared"><h4>Proposal, every watch</h4>${notesHtml(shared)}</div>` : "");
        const row = card.querySelector(".row");
        for (const col of DEV.COLUMNS) if (colOn(col)) row.appendChild(figure(scr, col));
        cards.appendChild(card);
      }
      board.appendChild(el);
    }
  }

  // ------------------------------------------------------------ toolbar
  function wire() {
    const tb = document.getElementById("toolbar");
    const cols = document.getElementById("cols");
    cols.innerHTML = DEV.COLUMNS.map(c => `<label><input type="checkbox" data-col="${c}"${colOn(c) ? " checked" : ""}> ${esc(DEV.BASE[c].name + (c === "today" ? " today" : c === "fenix7pro" ? " new" : ""))}</label>`).join("");
    tb.addEventListener("click", e => {
      const b = e.target.closest("button[data-scale], button[data-size]"); if (!b) return;
      if (b.dataset.scale) DOPT.scale = +b.dataset.scale; if (b.dataset.size) DOPT.size = b.dataset.size;
      sync(); save(); build();
    });
    tb.addEventListener("change", e => {
      const t = e.target; if (t.dataset.opt) DOPT[t.dataset.opt] = t.checked; if (t.dataset.col) DOPT.cols[t.dataset.col] = t.checked;
      save(); build();
    });
    sync();
  }
  function sync() {
    document.querySelectorAll("#toolbar button[data-scale]").forEach(b => b.setAttribute("aria-pressed", String(+b.dataset.scale === DOPT.scale)));
    document.querySelectorAll("#toolbar button[data-size]").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.size === DOPT.size)));
    document.querySelectorAll("#toolbar input[data-opt]").forEach(i => { i.checked = !!DOPT[i.dataset.opt]; });
  }

  return { build, wire, DOPT };
})();
