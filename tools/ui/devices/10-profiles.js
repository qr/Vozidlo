// ================================================================ DEVICES: profiles and input
// One profile per column of the board. "today" is the fēnix 7 Pro as the app draws it now (1.1.x), with the
// poc's own FM table; every other column is the proposal on one watch and stands for the products in its
// `covers` list (together: every product in the manifest). Which columns exist, what they cover and which are
// shown by default is generated (DEV_COLUMNS in 11-devdata.js, devdata.py columns()); names and subtitles are
// written from the device facts below, so adding a watch needs no edit here. Display, input and font facts
// come from DEV_DATA (11-devdata.js, generated from the SDK device files); the fēnix 7 Pro's data equals the
// poc's FM table. 11-devdata.js is therefore loaded before this file.
const DEV = (function () {
  // ------------------------------------------------------------ input profiles
  // What each physical control and gesture means on a profile. A0 is the fēnix with touch switched
  // off (or locked during an activity): the profile every action has to survive.
  const INPUT = {
    A: { id: "A", name: "5 buttons + touch", short: "fēnix", touch: true, keys: ["START", "BACK", "UP", "DOWN", "LIGHT"],
      select: ["START"], back: ["BACK"], next: ["DOWN"], prev: ["UP"], menu: ["hold UP"],
      tap: "Tap", swipeNext: "Swipe up", swipePrev: "Swipe down", swipeBack: "Swipe right", actionMenu: null },
    A0: { id: "A0", name: "5 buttons, no touch", short: "FR255 / fēnix, touch off", touch: false, keys: ["START", "BACK", "UP", "DOWN", "LIGHT"],
      select: ["START"], back: ["BACK"], next: ["DOWN"], prev: ["UP"], menu: ["hold UP"], actionMenu: null },
    B: { id: "B", name: "START + BACK + touch, MENU = hold BACK", short: "Venu 3 / 3S", touch: true, keys: ["START", "BACK"],
      select: ["START"], back: ["BACK"], next: [], prev: [], menu: ["hold BACK"],
      tap: "Tap", swipeNext: "Swipe up", swipePrev: "Swipe down", swipeBack: "Swipe right", actionMenu: null },
    C: { id: "C", name: "START + BACK + touch, no MENU", short: "no MENU key", touch: true, keys: ["START", "BACK"],
      select: ["START"], back: ["BACK"], next: [], prev: [], menu: [],
      tap: "Tap", swipeNext: "Swipe up", swipePrev: "Swipe down", swipeBack: "Swipe right", actionMenu: "Swipe left / indicator" }
  };

  // ------------------------------------------------------------ names
  // A product's short name: the device file's display name up to its first " / ", without ® and ™
  // ("fēnix® 8 47mm / 51mm / tactix® 8 ..." -> "fēnix 8 47mm").
  const shortName = pid => DEV_DATA[pid].name.split(" / ")[0].replace(/[®™]/g, "").replace(/\s+/g, " ").trim();
  // The short names of the products that match, in manifest order, without repeats: for copy that lists
  // watches ("no MENU key on vívoactive 6, Venu 4 41mm, ..."), so that copy follows the manifest.
  const namesWhere = pred => [...new Set(Object.keys(DEV_DATA).filter(p => pred(DEV_DATA[p], p)).map(shortName))];
  // "a, b and c"; with max, a longer list ends in "and N more" (the watch table has them all).
  const list = (names, max = Infinity) => names.length > max ? names.slice(0, max - 1).join(", ") + " and " + (names.length - max + 1) + " more"
    : names.length < 2 ? names.join("") : names.slice(0, -1).join(", ") + " and " + names[names.length - 1];
  const INPUT_SUB = { A: "5 buttons + touch", A0: "5 buttons, no touch", B: "hold BACK = MENU", C: "no MENU key" };
  function subFor(c) {
    const d = DEV_DATA[c.dev], others = c.covers.filter(p => p !== c.dev).map(shortName);
    const screen = d.shape === "rectangle" ? `${d.w} × ${d.h} rectangle` : `${d.w} round`;
    const fonts = d.fonts.medium.kind === "ttf" && d.displayType === "mip" ? ", TrueType fonts" : "";
    const also = others.length > 3 ? ` · also ${others.slice(0, 2).join(", ")} and ${others.length - 2} more` : others.length ? ` · also ${others.join(", ")}` : "";
    return `${screen} ${d.displayType === "mip" ? "MIP" : "AMOLED"}${fonts} · ${INPUT_SUB[c.input]}${d.mapView ? "" : " · no MapView"}${also}`;
  }

  // ------------------------------------------------------------ columns
  // input equals DEV_DATA[p].profile for every product p a column covers by construction; validate() still checks it.
  const COLS = [{ id: "today", dev: "fenix7pro", name: "fēnix 7 Pro", sub: "today (1.1.x)", input: "A", today: true, covers: [] }]
    .concat(DEV_COLUMNS.map(c => ({ id: c.id, dev: c.dev, name: shortName(c.dev), sub: subFor(c), input: c.input, covers: c.covers })));
  const BASE = Object.fromEntries(COLS.map(c => [c.id, c]));
  const COLUMNS = COLS.map(c => c.id);
  // Shown by default: today plus the generated choice (devdata.py columns()); the rest are toggles.
  const DEFAULT_ON = ["today"].concat(DEV_COLUMNS.filter(c => c.on).map(c => c.id));
  // Display corner radius of the Venu X1 in device px: estimated from the simulator artwork, not in the device files.
  const X1_CORNER = 58;
  // A device file without ppi (the FR255, FR255S, vívoactive 5) takes it, for true size only, from a watch with
  // the same screen (resolution and panel) that has one: the FR255 gets the FR955's 200, the vívoactive 5 the
  // Venu 3S's 325. With no such watch, 200.
  const PPI_FALLBACK = 200;
  function ppiFor(dd) {
    if (dd.ppi) return dd.ppi;
    const twin = Object.values(DEV_DATA).find(o => o.ppi && o.w === dd.w && o.h === dd.h && o.displayType === dd.displayType);
    return twin ? twin.ppi : PPI_FALLBACK;
  }

  // Product of a column for a product id (fitcheck --devices draws every product with its column's rules).
  const columnOf = pid => COLS.find(c => !c.today && c.covers.includes(pid));
  function validate() {
    const out = [], seen = {}, all = Object.keys(DEV_DATA);
    for (const c of COLS) for (const p of c.covers) {
      if (seen[p]) out.push(`${p} is covered by both ${seen[p]} and ${c.id}`); seen[p] = c.id;
      if (!DEV_DATA[p]) out.push(`${c.id} covers ${p}, which is not in DEV_DATA`);
      else if (DEV_DATA[p].profile !== c.input) out.push(`${c.id} has input ${c.input}, but ${p} is profile ${DEV_DATA[p].profile}`);
    }
    for (const p of all) if (!seen[p]) out.push(`${p} is in DEV_DATA but no column covers it`);
    for (const c of COLS) if (!c.today && !c.covers.includes(c.dev)) out.push(`${c.id} does not cover its own watch ${c.dev}`);
    return out;
  }

  // ------------------------------------------------------------ fonts
  // Device font file -> the CSS face the page draws its glyphs with (advances and heights are the device's).
  function cssFace(f) {
    const n = f.file;
    if (f.kind === "cft") return /NUMBER|BIONIC/.test(n) ? { weight: 700, family: "'Roboto Condensed'" } : { weight: 700, family: "Roboto" };
    if (n === "RobotoCondensed-Bold") return { weight: 700, family: "'Roboto Condensed'" };
    if (n === "Bionic_semibold" || n === "Bionic_Medium") return { weight: 600, family: "'Roboto Condensed'" };
    if (n === "Yantramanav-Regular") return { weight: 400, family: "Yantramanav" };
    if (n === "Roboto-Black") return { weight: 900, family: "Roboto" };
    return { weight: f.weight || 400, family: "Roboto" };
  }
  function describe(f) {
    const n = f.file;
    if (f.kind === "cft") return /BIONIC/.test(n) ? "Bionic bitmaps" : /NUMBER/.test(n) ? "number bitmaps" : "Roboto Bold bitmaps";
    return { "RobotoCondensed-Bold": "Roboto Condensed Bold", "Bionic_semibold": "Bionic Semibold", "Bionic_Medium": "Bionic Medium", "Roboto-Regular": "Roboto Regular",
      "Yantramanav-Regular": "Yantramanav", "Roboto-Black": "Roboto Black" }[n] || n;
  }

  // Logical metrics: every screen is drawn in a 260-wide frame scaled by s = w / 260, so a device font
  // of h px becomes h / s logical px. fontScale previews the user font size (vívoactive 6, Venu 4, X1: up to 1.4).
  function logicalFonts(dd, s, k) {
    const out = {};
    for (const key in dd.fonts) {
      const f = dd.fonts[key], m = { h: f.h * k / s, asc: f.asc * k / s, em: f.em == null ? null : f.em * k / s, w: f.w, a: f.a.map(a => a * k / s),
        file: f.file, kind: f.kind, face: cssFace(f) };
      m.adv = new Map(); [...m.w].forEach((ch, i) => m.adv.set(ch, m.a[i]));
      out[key] = m;
    }
    return out;
  }

  // o: {fontScale: 1 | 1.4, product: id}. Returns a fresh profile with everything the renderer needs.
  // o.product draws that product with the column's rules and its own facts and fonts (fitcheck --devices).
  function derive(id, o = {}) {
    const b = BASE[id], dd = DEV_DATA[o.product || b.dev];
    const P = Object.assign({}, b, { product: dd.id, dd });
    Object.assign(P, { w: dd.w, h: dd.h, shape: dd.shape === "rectangle" ? "rect" : "round", ppi: dd.ppi, touch: dd.touch,
      panel: dd.displayType === "mip" ? "MIP, 64 colours" : "AMOLED, " + dd.bpp + " bit", map: dd.mapView, launcher: dd.launcher,
      glance: dd.glance, fonts: describe(dd.fonts.medium) + ", " + describe(dd.fonts.numMed) + " numbers", family: dd.family });
    P.five = P.input === "A" || P.input === "A0";      // START, BACK, UP, DOWN, LIGHT
    P.s = P.w / 260;
    P.H = P.h / P.s;                                  // logical height (282 on the X1)
    P.offY = (P.H - 260) / 2;                         // the 260 square sits in the middle of the frame
    P.top = -P.offY; P.bottom = 260 + P.offY;         // frame edges in square coordinates
    P.k = P.input === "C" && o.fontScale ? o.fontScale : 1;
    P.fm = P.today ? null : logicalFonts(dd, P.s, P.k);   // null: the poc's FM (today)
    const mediumH = P.today ? FM.medium.h : dd.fonts.medium.h * P.k;
    // Theme.rowHeight(), in logical px: h / 4, at least FONT_MEDIUM + 16 and, for rows with a sub-label,
    // FONT_SMALL + FONT_XTINY + 8 (only binding at a large user font size; 65 on the fēnix either way).
    const subH = P.today ? FM.small.h + FM.xtiny.h : (dd.fonts.small.h + dd.fonts.xtiny.h) * P.k;
    P.rowH = Math.max(Math.floor(P.h / 4), mediumH + 16, subH + 8) / P.s;
    P.btn = P.five ? { start: -30, back: 30, down: 150, up: 180, light: 210 } : { start: -30, back: 30 };
    if (P.shape === "rect") {
      const ky = id => dd.keys.find(k => k.id === id).y / P.s - P.offY;
      P.keyY = { start: ky("enter"), back: ky("esc") };
      P.corner = X1_CORNER / P.s;
    }
    P.hint = dd.actionMenuHint ? (([x, y, w, h]) => ({ x: x / P.s, y: y / P.s - P.offY, w: w / P.s, h: h / P.s }))(dd.actionMenuHint) : null;
    P.mm = P.w / ppiFor(dd) * 25.4;                   // physical display width
    P.inputDef = INPUT[P.input];
    return P;
  }

  return { INPUT, BASE, COLUMNS, DEFAULT_ON, derive, validate, columnOf, cssFace, shortName, namesWhere, list, ppiFor, X1_CORNER, PPI_FALLBACK };
})();
