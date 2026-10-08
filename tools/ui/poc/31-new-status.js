// ================================================================ NEW status + charging (agent C)
// Status loop (C2), charging detail (C3), charge limit (C4), charging menus and profiles.
// Namespaces: window.NS (status pages) and window.NC (charging), both from this one IIFE.
(function () {
  const NS = {}, NC = {};
  const PAGES = ["lock", "fuel", "charging", "odo", "ac"];
  const TITLES = { lock: "Lock & doors", fuel: "Fuel & range", charging: "Charging", odo: "Odometer", ac: "Air conditioning" };
  const LIMIT_STOPS = [50, 60, 70, 80, 90, 100];
  const EX_ACTIVE = { soc: 80, charging: "CHARGING", chargeType: "AC", powerKw: "7.2", full: "18:40", remainMin: 95, ageMin: 3 };
  const EX_PROFILE = { name: "Home", here: true, target: 80, maxCurrent: "reduced", timers: ["22:00 Mon-Fri", "07:30 Sat, Sun"] };

  // ------------------------------------------------------------ shared bits
  // Native.menu2 draws rows that sit on the bezel edge (y < 16 or > 244) as "X…"; the round mask hides them on the
  // watch anyway, so clip them away here instead of touching core.
  function menu2(dc, o) { dc.setColor(T.TEXT_1, T.BG); dc.clear(); dc.setClip(0, 16, 260, 228); Ui.menu(dc, o); dc.clearClip(); }
  // arc = false on ring screens: the hint arc band (r 124..128) would sit on the SoC ring.
  function startGlyph(dc, start, arc = "accent") { Ui.drawBezelGlyph(dc, "start", start === "menu" ? "menu" : "refresh", T.TEXT_1, arc); }
  // Lines of xtiny text, centred, each fitted to the chord at its own y.
  function lines(dc, y0, pitch, list, color) {
    list.forEach((s, i) => { const y = y0 + i * pitch; dc.setColor(color || T.TEXT_1); dc.drawText(130, y, "xtiny", Ui.fit(dc, s, "xtiny", Ui.usable(y, y + FM.xtiny.h, 12)), J.CENTER); });
  }
  // Fixed-size chip for the lock grid (C2): outline + check when closed, amber fill + "!" when open.
  function gridChip(dc, x, y, w, h, c) {
    const warn = c.kind === "warn", fg = warn ? T.BLACK : T.TEXT_1;
    if (warn) { dc.setColor(T.WARNING); dc.fillRoundedRectangle(x, y, w, h, h / 2); }
    else { dc.setColor(T.RULE); dc.setPenWidth(1); dc.drawRoundedRectangle(x, y, w, h, h / 2); }
    const text = Ui.fit(dc, c.text, "xtiny", w - 30), tw = dc.getTextWidthInPixels(text, "xtiny"), cw = 12 + 4 + tw, x0 = Math.round(x + (w - cw) / 2);
    NIcons.draw(dc, warn ? "bang" : "check", x0 + 6, y + h / 2, 6, fg);
    dc.setColor(fg); dc.drawText(x0 + 16, y + Math.round(h / 2), "xtiny", text, J.LEFT | J.VCENTER);
  }
  // Lock page items: open items first (A9), sunroof dropped when unsupported.
  function lockItems(o) {
    const raw = { doors: NMOCK.doors, windows: NMOCK.windows, bonnet: NMOCK.bonnet, trunk: o.trunkOpen ? "OPEN" : NMOCK.trunk, lights: NMOCK.lights, sunroof: NMOCK.sunroof };
    const names = { doors: "Doors", windows: "Windows", bonnet: "Bonnet", trunk: "Trunk", lights: "Lights", sunroof: "Sunroof" };
    const items = Object.keys(names).filter(k => raw[k] !== "UNSUPPORTED").map(k => ({ text: names[k], kind: raw[k] === "OPEN" ? "warn" : "outline" }));
    return items.filter(i => i.kind === "warn").concat(items.filter(i => i.kind !== "warn"));
  }
  function heroValueIcon(dc, y, value, icon, color) {
    const wv = dc.getTextWidthInPixels(value, "numMed"), iw = 26, total = wv + 8 + iw, x0 = Math.round(130 - total / 2);
    dc.setColor(color || T.TEXT_1); dc.drawText(x0, y, "numMed", value, J.LEFT);
    NIcons.draw(dc, icon, x0 + wv + 8 + 13, y + Math.round(FM.numMed.asc * 0.62), 12, color || T.TEXT_1);
  }

  // ------------------------------------------------------------ status page (C2)
  // o = {page, ageMin, nodata, trunkOpen, indicator: "arc"|"dots", start: "refresh"|"menu", idx, count, merged}
  NS.page = function (dc, o = {}) {
    const page = o.page || "lock", idx = o.idx != null ? o.idx : PAGES.indexOf(page), count = o.count || PAGES.length;
    if (o.merged && page === "charging" && !o.nodata) { NC.detail(dc, Object.assign({}, o, { merged: true, idx, count })); return; }
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    Ui.title(dc, TITLES[page]);
    const age = o.ageMin != null ? o.ageMin : (page === "lock" ? NMOCK.statusAgeMin : NMOCK.ageMin);
    if (o.nodata) {
      dc.setColor(T.TEXT_1); dc.drawText(130, 98, "small", "No data yet", J.CENTER);
      dc.setColor(T.TEXT_2); dc.drawText(130, 136, "xtiny", "START to refresh", J.CENTER);
    } else if (page === "lock") {
      const raw = o.trunkOpen ? "TRUNK_OPENED" : NMOCK.lock, insecure = raw !== "YES";
      Ui.drawHero(dc, { word: Labels.lock(raw), icon: Icons.forLock(raw), y: 70, color: insecure ? T.WARNING : T.TEXT_1 });
      const items = lockItems(o), W = 89, H = 22, xs = [38, 133], ys = [116, 140, 164];
      items.slice(0, 6).forEach((c, i) => {
        const row = Math.floor(i / 2), alone = i === items.length - 1 && i % 2 === 0;
        gridChip(dc, alone ? Math.round(130 - W / 2) : xs[i % 2], ys[row], W, H, c);
      });
      Ui.drawAge(dc, 192, age);
    } else if (page === "fuel") {
      Ui.drawValueWithUnit(dc, 130, 64, String(NMOCK.totalRange), "km");
      lines(dc, 142, 20, [Labels.engine(NMOCK.primary.engine) + " " + NMOCK.primary.pct + "%", Labels.engine(NMOCK.secondary.engine) + " " + NMOCK.secondary.pct + "%"]);
      Ui.drawAge(dc, 192, age);
    } else if (page === "charging") {
      heroValueIcon(dc, 64, NMOCK.soc + "%", Icons.forCharging(NMOCK.charging) || "pluggedIn");
      lines(dc, 142, 20, [Labels.charging(NMOCK.charging), NMOCK.rangeKm + " km range"]);
      Ui.drawAge(dc, 192, age);
    } else if (page === "odo") {
      Ui.drawValueWithUnit(dc, 130, 64, String(NMOCK.odometer), "km", { gap: 3 });
      Ui.drawAge(dc, 192, age);
    } else if (page === "ac") {
      const on = NMOCK.climate !== "OFF";
      Ui.drawHero(dc, { word: Labels.climate(NMOCK.climate), icon: on ? "climate" : "fan", y: 70 });
      lines(dc, 128, 20, ["Windscreen heat " + Labels.state(NMOCK.heatFront).toLowerCase(), "Rear window heat " + Labels.state(NMOCK.heatRear).toLowerCase()]);
      Ui.drawAge(dc, 192, age);
    }
    Ui.drawPageIndicator(dc, idx, count, o.indicator || "arc");
    startGlyph(dc, o.start);
  };
  NS.pages = PAGES;
  NS.titles = TITLES;

  // Status ActionMenu (D4): over the lock page only Refresh; over the merged charging page also the charging actions.
  NS.actionItems = function (page, merged) { return merged && page === "charging" ? ["Refresh", "Charge limit", "Charging profiles"] : ["Refresh"]; };
  NS.actionMenu = function (dc, o = {}) {
    const page = o.page || "lock";
    Ui.actionMenu(dc, d => NS.page(d, Object.assign({}, o, { start: "menu" })), { items: NS.actionItems(page, o.merged), focus: o.focus || 0 });
  };

  // ------------------------------------------------------------ charging detail (C3)
  // o = {example, cable, merged, idx, count, indicator, start, limit, ageMin}
  NC.detail = function (dc, o = {}) {
    const ex = o.example ? EX_ACTIVE : null;
    const soc = ex ? ex.soc : NMOCK.soc, raw = o.cable ? "CONNECT_CABLE" : ex ? ex.charging : NMOCK.charging, active = raw === "CHARGING";
    const limit = o.limit != null ? o.limit : NMOCK.limit;
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    Ui.drawRing(dc, soc / 100, { fill: active ? T.ACCENT : T.TEXT_1, tick: limit != null ? limit / 100 : null });
    Ui.title(dc, "Charging");
    Ui.drawValueWithUnit(dc, 130, 58, soc + "%", null);
    const chip = o.cable ? { text: Labels.charging(raw), kind: "warn" } : { text: Labels.charging(raw), icon: active ? "bolt" : "pluggedIn" };
    Ui.drawChip(dc, 130, 134, chip);
    const rows = [];
    if (ex) { rows.push(ex.powerKw + " kW · " + Labels.chargeType(ex.chargeType)); rows.push("Full by " + ex.full + " (" + ex.remainMin + " min)"); }
    else if (NMOCK.rangeKm != null) rows.push(NMOCK.rangeKm + " km range");
    lines(dc, 160, 20, rows);
    Ui.drawAge(dc, 202, o.ageMin != null ? o.ageMin : ex ? ex.ageMin : o.cable ? 5 : NMOCK.ageMin);
    if (o.merged) { Ui.drawPageIndicator(dc, o.idx != null ? o.idx : 2, o.count || PAGES.length, o.indicator || "arc"); startGlyph(dc, o.start, false); }
    else { startGlyph(dc, "refresh", false); Ui.drawBezelGlyph(dc, "up", "menu", T.TEXT_2, false); }
  };

  // ------------------------------------------------------------ charge limit (C4)
  // o = {value, care}
  NC.limit = function (dc, o = {}) {
    const v = o.value || 80;
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    Ui.title(dc, "Charge limit", 36);
    LIMIT_STOPS.forEach((s, i) => {
      const a = (140 - i * 20) * Math.PI / 180, x = Math.round(130 + Math.cos(a) * 116), y = Math.round(130 + Math.sin(a) * 116);
      if (s === v) { dc.setColor(T.ACCENT); dc.fillCircle(x, y, 7); } else { dc.setColor(T.RULE); dc.fillCircle(x, y, 4); }
    });
    Ui.drawValueWithUnit(dc, 130, 124 - Math.floor(FM.numMed.h / 2), v + "%", null);
    if (o.care === v) Ui.drawChip(dc, 130, 166, { text: "Battery care", kind: "white", icon: "check" });
    Ui.drawBezelGlyph(dc, "up", "plus", T.TEXT_1, "dark");
    Ui.drawBezelGlyph(dc, "down", "minus", T.TEXT_1, "dark");
    Ui.drawBezelGlyph(dc, "start", "check", T.TEXT_1, "accent");
  };
  NC.limitItems = function (care) { return LIMIT_STOPS.map(s => ({ label: s + "%", sub: s === care ? "Recommended" : null })); };
  NC.limitMenu = function (dc, o = {}) {
    const v = o.value || 80;
    menu2(dc, { title: "Charge limit", items: NC.limitItems(o.care), focus: LIMIT_STOPS.indexOf(v) });
  };

  // ------------------------------------------------------------ menus, mode, profiles
  NC.menuItems = [{ label: "Refresh", icon: "refresh" }, { label: "Set charge limit", icon: "battery" }, { label: "Charging profiles", icon: "list" }];
  NC.menu = function (dc, o = {}) { menu2(dc, { title: "Charging", items: NC.menuItems, focus: o.focus || 0 }); };
  NC.mode = function (dc, o = {}) {
    menu2(dc, { title: "Charge mode", items: [{ label: "Manual", check: true }, { label: "Timer", check: false }, { label: "Preferred times", check: false }], focus: o.focus || 0 });
  };
  NC.profilesUnsupported = function (dc) {
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    Ui.title(dc, "Charging profiles", 40);
    dc.setColor(T.TEXT_1); dc.drawText(130, 104, "small", "Not supported", J.CENTER);
    dc.setColor(T.TEXT_2); dc.drawText(130, 136, "small", "by this car", J.CENTER);
  };
  // o = {idx, count, indicator}
  NC.profile = function (dc, o = {}) {
    const p = EX_PROFILE;
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    Ui.title(dc, "Charging profiles", 40);
    Ui.drawHero(dc, { word: p.name, y: 70 });
    if (p.here) Ui.drawChip(dc, 130, 108, { text: "Here", kind: "white", icon: "pin" });
    lines(dc, 136, 19, ["Target " + p.target + "%", "Max current " + p.maxCurrent]);
    lines(dc, 178, 19, p.timers, T.TEXT_2);
    Ui.drawPageIndicator(dc, o.idx || 0, o.count || 2, o.indicator || "arc");
  };

  // ------------------------------------------------------------ cards
  const SEC_ST = "status", SEC_CH = "charging";
  const stFixes = ["A3", "A8", "A16", "A17", "C2"];
  CARDS.push(
    { id: "st-lock", section: SEC_ST, name: "Lock & doors",
      neu: [
        { label: "D7 native arc · D4 refresh glyph", draw: dc => NS.page(dc, { page: "lock" }), keys: { "UP/DOWN": "Previous / next page (wraps)", START: "Refresh", BACK: "Home" }, decision: "D7" },
        { label: "D7 custom dots", draw: dc => NS.page(dc, { page: "lock", indicator: "dots" }), keys: { "UP/DOWN": "Previous / next page (wraps)", START: "Refresh" }, decision: "D7" },
        { label: "D4 START opens action menu", draw: dc => NS.page(dc, { page: "lock", start: "menu" }), keys: { "UP/DOWN": "Pages", START: "Action menu (Refresh)" }, decision: "D4" }],
      fixes: ["A3", "A8", "A9", "A15", "A16", "A17", "A21", "C2", "D4", "D7"],
      changed: ["\"LOCKED\" in the number font becomes padlock + \"Locked\" in FONT_MEDIUM.", "Three sub-lines become a 2x3 chip grid: Doors, Windows, Bonnet, Trunk, Lights all visible (sunroof unsupported, dropped).",
        "Closed = outline chip with check; open = amber chip with \"!\", sorted first.", "\"1/5\" counter and quota line dropped; page indicator on the left instead.", "Bottom hint replaced by a refresh glyph at START (or a menu glyph for D4)."],
      notes: ["Dots: current filled accent r 4, others grey r 3 at r 118, so size also marks the page in monochrome.", "Taps no longer refresh (A15); refresh only on START or the action menu."] },
    { id: "st-fuel", section: SEC_ST, name: "Fuel & range",
      neu: [{ label: "", draw: dc => NS.page(dc, { page: "fuel" }), keys: { "UP/DOWN": "Pages", START: "Refresh" } }],
      fixes: stFixes, changed: ["\"436\" in the number font, \"km\" in FONT_MEDIUM grey on the same baseline.", "\"GASOLINE 62%\" becomes \"Petrol 62%\" (Labels.engine)."], notes: [] },
    { id: "st-charging", section: SEC_ST, name: "Charging page",
      neu: [
        { label: "D2 separate: status page", draw: dc => NS.page(dc, { page: "charging" }), keys: { "UP/DOWN": "Pages", START: "Refresh" }, decision: "D2" },
        { label: "D2 merged: charging page", draw: dc => NS.page(dc, { page: "charging", merged: true }), keys: { "UP/DOWN": "Pages", START: "Refresh", MENU: "Charging menu" }, decision: "D2" }],
      fixes: ["A8", "A16", "A19", "C2", "C3", "D2"],
      changed: ["\"READY_FOR_CHARGING\" becomes \"Plugged in\".", "Merged variant: this page is the C3 charging detail, so the separate Charging view goes away."],
      notes: [{ flag: "Merged + native arc: the indicator (r 116..124) sits right against the SoC ring (r 124..128); with dots it reads better." }] },
    { id: "st-odo", section: SEC_ST, name: "Odometer",
      neu: [{ label: "", draw: dc => NS.page(dc, { page: "odo" }), keys: { "UP/DOWN": "Pages", START: "Refresh" } }],
      fixes: stFixes, changed: ["Digits in the number font, \"km\" in FONT_MEDIUM with a 3 px gap (tight: about 206 of 210 px)."], notes: ["If a seven-digit odometer shows up, the unit moves to a sub-line."] },
    { id: "st-ac", section: SEC_ST, name: "Air conditioning",
      neu: [{ label: "", draw: dc => NS.page(dc, { page: "ac" }), keys: { "UP/DOWN": "Pages", START: "Refresh" } }],
      fixes: stFixes, changed: ["\"OFF\" in the number font becomes fan icon + \"Off\" in FONT_MEDIUM.", "\"Front window heat OFF\" becomes \"Windscreen heat off\"."], notes: [] },
    { id: "st-ac-stale", section: SEC_ST, name: "Air conditioning, 17 h old",
      neu: [{ label: "", draw: dc => NS.page(dc, { page: "ac", ageMin: 17 * 60 }), keys: {} }],
      fixes: ["A17", "A21", "C2"], changed: ["Stale age turns amber with \"!\" (was red), \"! 17 h ago\"."], notes: [] },
    { id: "st-nodata", section: SEC_ST, name: "Section without data",
      neu: [{ label: "", draw: dc => NS.page(dc, { page: "ac", nodata: true }), keys: { START: "Refresh" } }],
      fixes: ["A7", "A8", "C2"], changed: ["\"—\" in the number font plus a 255 px yellow line become \"No data yet\" and a grey \"START to refresh\"."], notes: [] },
    { id: "st-trunk", section: SEC_ST, order: 207, name: "Lock & doors, trunk open",
      neu: [{ label: "", draw: dc => NS.page(dc, { page: "lock", trunkOpen: true }), keys: { START: "Refresh" } }],
      fixes: ["A9", "A21", "C2"], changed: ["New state: hero turns amber \"Trunk open\" with the open icon; amber \"! Trunk\" chip sorted first, never hidden."],
      notes: ["Assumes the API reports TRUNK_OPENED as the lock state; with YES plus an open trunk the hero stays \"Locked\" and only the chip turns amber."] },
    { id: "st-actionmenu", section: SEC_ST, order: 208, name: "Status action menu (D4)",
      neu: [
        { label: "From the lock page", draw: dc => NS.actionMenu(dc, { page: "lock" }), keys: { START: "Run", BACK: "Close" }, decision: "D4" },
        { label: "From the merged charging page", draw: dc => NS.actionMenu(dc, { page: "charging", merged: true }), keys: { "UP/DOWN": "Move", START: "Run", BACK: "Close" }, decision: "D4" }],
      fixes: ["D4", "B6"], changed: ["New: START opens Garmin's ActionMenu with Refresh first (quota friction, same on every page)."],
      notes: ["On the lock page the menu has only Refresh: two presses for what the glyph variant does in one."] },
    { id: "ch-detail", section: SEC_CH, name: "Charging detail",
      neu: [
        { label: "D2 separate view", draw: dc => NC.detail(dc, {}), keys: { START: "Refresh", MENU: "Charging menu (hold UP)", BACK: "Home" }, decision: "D2" },
        { label: "D2 merged: page 3 of Status", draw: dc => NC.detail(dc, { merged: true }), keys: { "UP/DOWN": "Status pages", START: "Refresh", MENU: "Charging menu" }, decision: "D2" }],
      fixes: ["A3", "A15", "A16", "A17", "A19", "C3", "D2"],
      changed: ["SoC ring around the bezel (limit tick when the car reports a limit).", "\"Ready to charge\" headline becomes \"100%\" hero + \"Plugged in\" chip.",
        "\"Type: Not charging\", \"Power: —\" etc. dropped: rows only when there is data (here \"36 km range\").", "Bottom hint replaced by a refresh glyph at START and a menu glyph at UP."],
      notes: [{ flag: "Today this screen is unreachable with buttons: on home UP/DOWN move the tile focus (verified on the watch). NEW home exposes it as a Charging tile or row." }, "\"36 km range\" kept as a row so the merged variant loses nothing from the old status page."] },
    { id: "ch-active", section: SEC_CH, name: "Charging detail, while charging",
      neu: [{ label: "Example", draw: dc => NC.detail(dc, { example: true }), keys: { START: "Refresh", MENU: "Charging menu" } }],
      fixes: ["C3", "A16"], changed: ["Accent ring at 80 %, bolt chip \"Charging\", \"7.2 kW · AC\", \"Full by 18:40 (95 min)\".", "Rate line (km/h) dropped to keep two rows."],
      notes: ["Example values, not from the mock."] },
    { id: "ch-cable", section: SEC_CH, name: "Cable warning",
      neu: [{ label: "Example", draw: dc => NC.detail(dc, { cable: true }), keys: { START: "Refresh" } }],
      fixes: ["A21", "C3"], changed: ["Orange sentence \"No cable appears to be connected\" becomes an amber chip \"! Plug in\"."], notes: ["Example state, not from the mock."] },
    { id: "ch-menu", section: SEC_CH, name: "Charging menu",
      neu: [{ label: "", draw: dc => NC.menu(dc), keys: { START: "Open", BACK: "Charging" } }],
      fixes: ["A20", "B6"], changed: ["Icons per item (refresh, battery, list); slide left in, right out."], notes: ["Set charge mode stays hidden: the mock reports no available modes."] },
    { id: "ch-limit", section: SEC_CH, name: "Charge limit",
      neu: [
        { label: "Stepper (C4)", draw: dc => NC.limit(dc, { value: 80 }), keys: { "UP / swipe up": "+10%", "DOWN / swipe down": "−10%", START: "Set", BACK: "Back" } },
        { label: "Menu2 50..100", draw: dc => NC.limitMenu(dc, { value: 80 }), keys: { "UP/DOWN": "Move", START: "Set", BACK: "Back" } }],
      fixes: ["A3", "A19", "C4", "B6"], changed: ["Title in the accent at y 36; six stop dots on the bottom arc (50 % left, 100 % right), current one accent.", "\"UP/DOWN adjust - SELECT set\" replaced by + / − glyphs at UP/DOWN and a check at START.", "Swipe up now increases (A19; today swipe up decreases)."],
      notes: ["Menu2 variant: native list focused on the current value, \"Recommended\" on the battery-care value."] },
    { id: "ch-limit-care", section: SEC_CH, name: "Charge limit, battery-care match",
      neu: [
        { label: "Stepper, Example", draw: dc => NC.limit(dc, { value: 80, care: 80 }), keys: {} },
        { label: "Menu2, Example", draw: dc => NC.limitMenu(dc, { value: 80, care: 80 }), keys: {} }],
      fixes: ["A21", "C4"], changed: ["Green \"Recommended (battery care)\" line becomes a white \"Battery care\" chip with check (green is for transient success only)."], notes: ["Example: battery-care target 80 %."] },
    { id: "ch-mode", section: SEC_CH, name: "Charge mode",
      neu: [{ label: "Example", draw: dc => NC.mode(dc), keys: { START: "Set mode", BACK: "Back" } }],
      fixes: ["A16", "B6"], changed: ["\"Current\" sub-label becomes a single-choice check on the active mode."], notes: ["Example modes; only shown when the car lists any."] },
    { id: "ch-profiles", section: SEC_CH, name: "Charging profiles",
      neu: [{ label: "", draw: dc => NC.profilesUnsupported(dc), keys: { BACK: "Back" } }],
      fixes: ["A4", "A18"], changed: ["Uppercase grey header becomes the accent title \"Charging profiles\" at y 34.", "\"by this car\" in grey."], notes: [] },
    { id: "ch-profile-ex", section: SEC_CH, name: "Charging profile page",
      neu: [{ label: "Example", draw: dc => NC.profile(dc, { idx: 0, count: 2 }), keys: { "UP/DOWN": "Next profile", BACK: "Back" } }],
      fixes: ["A19", "A21", "B6"], changed: ["Green \"Home (here)\" becomes \"Home\" + white pin chip \"Here\".", "\"Target: 80%\" becomes \"Target 80%\"; timers as \"22:00 Mon-Fri\".", "\"1/2 - UP/DOWN\" hint replaced by the page indicator."],
      notes: ["Example profile.", "Weekday ranges use a hyphen: the en dash is not in the measured font set."] }
  );

  // ------------------------------------------------------------ simulator views
  const wrap = (i, n) => (i + n) % n;
  const refreshed = () => ({ toast: { text: "Refreshed", icon: "check" } });

  SIM_VIEWS["new:statusLoop"] = {
    newDesign: true,
    init(o = {}) {
      const p = o.page == null ? 0 : typeof o.page === "number" ? o.page : Math.max(0, PAGES.indexOf(o.page));
      return { d2: o.d2 || "separate", d4: o.d4 || "refresh", d7: o.d7 || "arc", idx: p, menu: null };
    },
    draw(dc, s) {
      const o = { page: PAGES[s.idx], idx: s.idx, count: PAGES.length, indicator: s.d7, start: s.d4, merged: s.d2 === "merged" };
      if (!s.menu) { NS.page(dc, o); return; }
      if (s.menu.kind === "action") Ui.actionMenu(dc, d => NS.page(d, o), { items: s.menu.items, focus: s.menu.focus });
      else NC.menu(dc, { focus: s.menu.focus });
    },
    key(k, s) {
      const merged = s.d2 === "merged", page = PAGES[s.idx];
      if (s.menu) {
        const n = s.menu.items.length;
        if (k === "UP" || k === "SWIPE_DOWN") { s.menu.focus = Math.max(0, s.menu.focus - 1); return null; }
        if (k === "DOWN" || k === "SWIPE_UP") { s.menu.focus = Math.min(n - 1, s.menu.focus + 1); return null; }
        if (k === "BACK") { s.menu = null; return null; }
        if (k === "START" || k === "TAP") {
          const it = s.menu.items[s.menu.focus], label = typeof it === "string" ? it : it.label; s.menu = null;
          if (label === "Refresh") return refreshed();
          if (label === "Charge limit" || label === "Set charge limit") return { push: "new:chargeLimit", o: {} };
          if (label === "Charging profiles") return { push: "new:chargingProfiles", o: {} };
        }
        return null;
      }
      if (k === "UP" || k === "SWIPE_DOWN") { s.idx = wrap(s.idx - 1, PAGES.length); return null; }
      if (k === "DOWN" || k === "SWIPE_UP") { s.idx = wrap(s.idx + 1, PAGES.length); return null; }
      if (k === "START") {
        if (s.d4 === "menu") { s.menu = { kind: "action", items: NS.actionItems(page, merged), focus: 0 }; return null; }
        return refreshed();
      }
      if (k === "MENU" && merged && page === "charging") { s.menu = { kind: "menu2", items: NC.menuItems, focus: 0 }; return null; }
      if (k === "BACK") return { pop: true };
      return null;   // TAP: no refresh on tap (A15)
    }
  };

  SIM_VIEWS["new:chargingDetail"] = {
    newDesign: true,
    init(o = {}) { return { example: !!o.example, cable: !!o.cable, menu: null }; },
    draw(dc, s) { if (s.menu) NC.menu(dc, { focus: s.menu.focus }); else NC.detail(dc, { example: s.example, cable: s.cable }); },
    key(k, s) {
      if (s.menu) {
        if (k === "UP" || k === "SWIPE_DOWN") { s.menu.focus = Math.max(0, s.menu.focus - 1); return null; }
        if (k === "DOWN" || k === "SWIPE_UP") { s.menu.focus = Math.min(NC.menuItems.length - 1, s.menu.focus + 1); return null; }
        if (k === "BACK") { s.menu = null; return null; }
        if (k === "START" || k === "TAP") {
          const label = NC.menuItems[s.menu.focus].label; s.menu = null;
          if (label === "Refresh") return refreshed();
          if (label === "Set charge limit") return { push: "new:chargeLimit", o: {} };
          if (label === "Charging profiles") return { push: "new:chargingProfiles", o: {} };
        }
        return null;
      }
      if (k === "START") return refreshed();
      if (k === "MENU") { s.menu = { focus: 0 }; return null; }
      if (k === "BACK") return { pop: true };
      return null;
    }
  };

  SIM_VIEWS["new:chargeLimit"] = {
    newDesign: true,
    init(o = {}) { return { value: LIMIT_STOPS.includes(o.value) ? o.value : 80, care: o.care != null ? o.care : null }; },
    draw(dc, s) { NC.limit(dc, { value: s.value, care: s.care }); },
    key(k, s) {
      if (k === "UP" || k === "SWIPE_UP") { s.value = Math.min(100, s.value + 10); return null; }
      if (k === "DOWN" || k === "SWIPE_DOWN") { s.value = Math.max(50, s.value - 10); return null; }
      if (k === "START") return { toast: { text: "Limit set to " + s.value + "%", icon: "check" } };
      if (k === "BACK") return { pop: true };
      return null;
    }
  };

  SIM_VIEWS["new:chargingProfiles"] = {
    newDesign: true,
    init() { return {}; },
    draw(dc) { NC.profilesUnsupported(dc); },
    key(k) { return k === "BACK" ? { pop: true } : null; }
  };

  window.NS = NS;
  window.NC = NC;
})();
