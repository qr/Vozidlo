// ================================================================ NEW home (agent B)
// D1 variants: (a) grid per C1a, (b) hero + action list per C1b. Both expose Charging with buttons.
(function () {
  const NH = {};

  // ---------------------------------------------------------------- data
  // Tile order (TileOrder): climate, charging, Charging detail, Find my car, Status, Settings.
  NH.TILES = ["Start climate", "Stop climate", "Start charging", "Stop charging", "Charging", "Find my car", "Status", "Settings"];
  // First launch: operations unknown, so every action is offered (ventilation included).
  NH.TILES_UNKNOWN = ["Start climate", "Stop climate", "Start ventilation", "Stop ventilation", "Start charging", "Stop charging", "Charging", "Find my car", "Status", "Settings"];
  // Grid rule: up to 8 tiles (four full rows) are shown as is; above 8 the first 7 plus "More".
  NH.GRID_CAP = 8;
  NH.capGrid = tiles => tiles.length <= NH.GRID_CAP ? tiles.slice() : tiles.slice(0, NH.GRID_CAP - 1).concat(["More"]);
  NH.moreItems = tiles => tiles.length <= NH.GRID_CAP ? [] : tiles.slice(NH.GRID_CAP - 1);
  NH.ICON = { "Charging": "bolt", "Find my car": "pin", "Status": "list", "Settings": "gear" };
  NH.mockStrip = () => ({ soc: NMOCK.soc, lock: NMOCK.lock, charging: NMOCK.charging, climate: NMOCK.climate });
  NH.UNKNOWN_STRIP = { soc: null, lock: null, charging: null, climate: null };
  NH.VISIBLE_ROWS = 3;
  NH.rowsOf = n => Math.ceil(n / 2);
  // GridScroll.offsetFor: minimal scroll that keeps `row` visible, clamped to the content.
  NH.offsetFor = (cur, row, vis, total) => {
    if (vis <= 0 || total <= 0) return 0;
    let o = cur; if (row < o) o = row; else if (row > o + vis - 1) o = row - vis + 1;
    return Math.max(0, Math.min(o, Math.max(0, total - vis)));
  };

  const lockWarn = raw => raw === "NO" || raw === "OPENED" || raw === "TRUNK_OPENED";
  const ageOf = o => o.ageMin == null ? NMOCK.ageMin : o.ageMin;

  // ---------------------------------------------------------------- shared parts
  // Status line: command result, error, or the data age (amber "! 17 h" when stale).
  function statusLine(dc, y, o, maxW) {
    const m = o.msg;
    if (m && m.kind === "sent") {
      const t = Ui.fit(dc, m.text || "Sent", "xtiny", maxW - 16), w = dc.getTextWidthInPixels(t, "xtiny") + 16, x0 = Math.round(130 - w / 2);
      NIcons.draw(dc, "check", x0 + 6, y + 10, 6, T.POSITIVE);
      dc.setColor(T.TEXT_1); dc.drawText(x0 + 16, y, "xtiny", t, J.LEFT);
    } else if (m && m.kind === "error") {
      dc.setColor(T.DESTRUCTIVE); dc.drawText(130, y, "xtiny", Ui.fit(dc, "! " + m.text, "xtiny", maxW), J.CENTER);
    } else {
      const min = ageOf(o);
      Ui.drawAge(dc, y, min, Age.stale(min) ? { short: true } : {});
    }
  }
  function chargeChip(raw) {
    if (raw === "CHARGING") return { kind: "accent", icon: "bolt", text: "Charging" };
    if (raw === "CONNECT_CABLE") return { kind: "warn", text: "Plug in" };
    if (Icons.forCharging(raw)) return { icon: "pluggedIn", text: Labels.charging(raw) };
    return null;
  }
  function lockChip(raw) {
    if (raw == null) return { text: "—" };
    if (lockWarn(raw)) return { kind: "warn", text: Labels.lock(raw) };
    return { icon: "locked", text: Labels.lock(raw) };
  }

  // ---------------------------------------------------------------- (a) grid, C1a
  // Black band: "100%" small y 14; plug · padlock "Locked" · climate at y 45 (icons cy 54); rule at y 66.
  function gridStrip(dc, s) {
    dc.setColor(T.TEXT_1); dc.drawText(130, 14, "small", s.soc == null ? "—" : s.soc + "%", J.CENTER);
    const ci = Icons.forCharging(s.charging), cl = Icons.forClimate(s.climate), cy = 54;
    let w, drawMid;
    if (s.lock != null && lockWarn(s.lock)) {
      const chip = { kind: "warn", text: Labels.lock(s.lock) }; w = Ui.chipWidth(dc, chip);
      drawMid = x => Ui.drawChip(dc, x + w / 2, 44, chip);
    } else {
      const label = s.lock == null ? "—" : Labels.lock(s.lock), iw = s.lock == null ? 0 : 18;
      w = iw + dc.getTextWidthInPixels(label, "xtiny");
      drawMid = x => { if (iw) NIcons.draw(dc, "locked", x + 7, cy, 7, T.TEXT_1); dc.setColor(T.TEXT_1); dc.drawText(x + iw, 45, "xtiny", label, J.LEFT); };
    }
    const gap = 12, total = w + (ci ? 14 + gap : 0) + (cl ? 14 + gap : 0);
    let x = Math.round(130 - total / 2);
    if (ci) { NIcons.draw(dc, ci, x + 7, cy, 7, s.charging === "CHARGING" ? T.ACCENT : T.TEXT_1); x += 14 + gap; }
    drawMid(x); x += w + gap;
    if (cl) NIcons.draw(dc, cl, x + 7, cy, 7, T.TEXT_1);
    dc.setColor(T.RULE); dc.fillRectangle(20, 66, 220, 1);
  }
  // Tile 90 x 44 r 8: RULE outline + white label, or accent fill + black label + 2 px white outline.
  function tile(dc, x, y, label, focused) {
    const lines = Ui.wrap(dc, label, "xtiny", [76], 2);
    if (focused) {
      dc.setColor(dc.mono ? T.TEXT_1 : T.ACCENT); dc.fillRoundedRectangle(x, y, 90, 44, 8);
      if (!dc.mono) { dc.setColor(T.TEXT_1); dc.setPenWidth(2); dc.drawRoundedRectangle(x, y, 90, 44, 8); dc.setPenWidth(1); }
    } else { dc.setColor(T.RULE); dc.setPenWidth(1); dc.drawRoundedRectangle(x, y, 90, 44, 8); }
    dc.setColor(focused ? T.BLACK : T.TEXT_1); dc.drawText(x + 45, y + 22, "xtiny", lines.join("\n"), J.CENTER | J.VCENTER);
  }
  // o: {tiles, focus, scroll (rows), strip {soc, lock, charging, climate}, msg {text, kind: sent|error}, ageMin}
  NH.grid = function (dc, o = {}) {
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const tiles = o.tiles || NH.TILES, focus = o.focus || 0, scroll = o.scroll || 0, rows = NH.rowsOf(tiles.length);
    gridStrip(dc, o.strip || NH.mockStrip());
    dc.setClip(0, 68, 260, 144);
    tiles.forEach((t, i) => {
      const x = i % 2 ? 135 : 35, y = 70 + (Math.floor(i / 2) - scroll) * 48;
      if (y + 44 < 68 || y > 212) return;
      tile(dc, x, y, t, i === focus);
    });
    dc.clearClip();
    Ui.drawScrollArc(dc, scroll, NH.VISIBLE_ROWS, rows);
    statusLine(dc, 214, o, 142);
    Ui.drawHintArc(dc, "start", "accent");
  };

  // ---------------------------------------------------------------- (b) hero + action list, C1b
  // o: {rows, focus, strip, msg, ageMin}. Ring margin 12 for every line.
  // Mirrors app/source/ui/HomeMenu.mc + HomeHero.mc: a CustomMenu with rows of ROW_H, of which only
  // the focused row and its two neighbours are drawn, the hero in the 98 px title area above row 0
  // (drawn at focus 0 only, so it slides in coming back to row 0 and is blank once row 1 has the focus), laid out bottom-up: status line, chips, then the SoC in the largest
  // font whose digits clear y 12 and fit the chord (HomeHero.HeroFit). o.shift: see Ui.menu.
  NH.ROW_H = Ui.ROW_H;
  NH.HERO_BOTTOM = 130 - Math.floor(NH.ROW_H / 2);
  NH.hero = function (dc, o = {}) {
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const rows = o.rows || NH.TILES, f = Math.max(0, Math.min(rows.length - 1, o.focus || 0)), s = o.strip || NH.mockStrip();
    const H = NH.ROW_H, shift = o.shift || 0, heroDy = Math.round(-f * H + shift);
    if (f === 0) {
      dc.translate(0, heroDy);
      const statusTop = NH.HERO_BOTTOM - FM.xtiny.h;
      const chips = [lockChip(s.lock), chargeChip(s.charging)].filter(Boolean);
      if (Icons.forClimate(s.climate)) chips.push({ icon: "climate", text: Labels.climate(s.climate) });
      const chipH = 21, chipsTop = chips.length ? statusTop - 2 - chipH : statusTop, baseline = chipsTop - 4;
      statusLine(dc, statusTop, o, Ui.usable(statusTop, statusTop + FM.xtiny.h, 12));
      if (chips.length) {
        const maxW = Ui.usable(chipsTop, chipsTop + chipH, 12);
        let keep = chips.length;
        const widthOf = n => chips.slice(0, n).reduce((a, c) => a + Ui.chipWidth(dc, c), 0) + 6 * (n - 1);
        while (keep > 0 && widthOf(keep) > maxW) keep--;
        if (keep) Ui.drawChipRow(dc, chipsTop, chips.slice(0, keep));
      }
      if (s.soc == null) Ui.drawHero(dc, { word: "—", y: baseline - FM.medium.asc });
      else {
        const value = String(s.soc), unitW = dc.getTextWidthInPixels("%", "small") + 4;
        let font = "medium";
        for (const fnt of ["numMed", "numMild", "medium"]) {
          const top = baseline - Math.floor((FM[fnt].asc * 4 + 4) / 5);
          if (top < 12) continue;
          if (dc.getTextWidthInPixels(value, fnt) + unitW <= Ui.usable(top, baseline, 12)) { font = fnt; break; }
        }
        Ui.drawValueWithUnit(dc, 130, baseline - FM[font].asc, value, "%", { num: font, unitFont: "small" });
      }
      dc.translate(0, -heroDy);
    }
    // Rows: centre y = 130 + (i - f) * H; only the focused row and its neighbours are drawn. While
    // o.shift is set they slide into place; the hero and the row leaving are blank (see Ui.menu).
    for (let i = Math.max(0, f - 1); i <= Math.min(rows.length - 1, f + 1); i++) {
      const cy = Math.round(130 + (i - f) * H + shift);
      if (i === f) Ui.focusPill(dc, 24, cy - 25, 212, 51, rows[i], "medium");
      else {
        const at = 130 + (i - f) * H, w = Ui.usable(at - 14, at + 15, 8);   // fitted where it settles, as in the app
        dc.setColor(T.TEXT_2); dc.drawText(130, cy, "tiny", Ui.fit(dc, rows[i], "tiny", Math.min(193, w)), J.CENTER | J.VCENTER);
      }
    }
    Ui.drawRing(dc, s.soc == null ? 0 : s.soc / 100, { fill: s.charging === "CHARGING" ? T.ACCENT : T.TEXT_1 });
  };

  // ---------------------------------------------------------------- cards
  const KEYS_A = { START: "Run focused tile", "UP/DOWN": "Move tile focus (no wrap)", "Swipe up/down": "Scroll one row", Tap: "Run tile", BACK: "Exit app" };
  const KEYS_B = { START: "Run focused row", "UP/DOWN": "Previous / next row, wrapping at both ends", "Swipe": "Move focus", Tap: "Run row", BACK: "Exit app" };
  const A = (draw, keys = KEYS_A) => ({ label: "a · grid", draw, keys, decision: "D1", fitcheck: true });
  const B = (draw, keys = KEYS_B) => ({ label: "b · hero list", draw, keys, decision: "D1", fitcheck: true });
  const ord = id => OLD_SCREENS[id] ? OLD_SCREENS[id].order : undefined;
  const REACH = [
    "How Charging and Status are reached: (a) the Charging tile (row 3) and the Status tile (row 4); UP/DOWN move the focus, as verified on the watch.",
    "(b) Charging and Status are rows; the list wraps at both ends like Garmin's own menus (1.1.0 opened them past the ends, which read as a screen opening by itself). A tap on the hero opens Status."
  ];
  const lastIdx = NH.TILES.length - 1, lastScroll = NH.rowsOf(NH.TILES.length) - NH.VISIBLE_ROWS;
  const unknownA = NH.capGrid(NH.TILES_UNKNOWN);
  const toastOn = under => dc => Native.toast(dc, under, { text: "Command sent", icon: "check" });

  CARDS.push(
    { id: "home-mock", section: "home", order: ord("home-mock"), name: "Home",
      neu: [A(dc => NH.grid(dc, {})), B(dc => NH.hero(dc, {}))],
      fixes: ["A6", "A10", "A11", "A12", "A13", "A21", "C1a", "C1b", "D1"],
      changed: ["Strip: \"100%\" on top, plug · padlock \"Locked\" below (A6); no raw enum, nothing cut off.",
        "(a) New Charging tile: Charging detail is reachable with buttons.",
        "(a) Black band with a rule at y 66; tiles clipped to y 68..212 (A10).",
        "(a) Outline tiles, focused tile accent with black label (A21).",
        "(a) Scroll arc on the right bezel replaces the carets.",
        "No text hint and no UP/DOWN glyphs; START hint arc only.",
        "(b) SoC ring, hero \"100%\", chips and the age in the title area, the focused row as accent pill, one row below (rows of 65 px; only the focused row and its neighbours are drawn, so three sit close together and the rest stays off screen)."],
      notes: REACH.concat(["Mock: 8 tiles fill four rows, so no More. Rule chosen: up to 8 tiles shown as is, above 8 the first 7 plus More.",
        { flag: "D1 open: (a) keeps the custom grid; (b) needs a CustomMenu with the hero as title area." }]) },
    { id: "home-scrolled", section: "home", order: ord("home-scrolled"), name: "Home, scrolled to Settings",
      neu: [A(dc => NH.grid(dc, { focus: lastIdx, scroll: lastScroll })), B(dc => NH.hero(dc, { focus: lastIdx }))],
      fixes: ["A10", "A11", "C1a", "C1b", "D1"],
      changed: ["(a) Tiles stay inside the clip: nothing covers the band.", "(a) Scroll arc thumb at the bottom.",
        "(b) Focus on the last row: the hero has scrolled away; one row above the pill, none below."],
      notes: REACH.concat(["Returning from Settings keeps focus and scroll (A11); the OLD app resets to the top."]) },
    { id: "home-unknown", section: "home", order: ord("home-unknown"), name: "Home, first launch (no operations cached)",
      neu: [A(dc => NH.grid(dc, { tiles: unknownA, strip: NH.UNKNOWN_STRIP })),
            B(dc => NH.hero(dc, { rows: NH.TILES_UNKNOWN, strip: NH.UNKNOWN_STRIP }))],
      fixes: ["A6", "A8", "A14", "C1a", "C1b", "D1"],
      changed: ["Unknown SoC and lock show \"—\" (no number-font letters).", "(a) 10 tiles: first 7 plus More; Charging is tile 7.",
        "(b) No cap: all 10 rows, including ventilation.", "(b) Hero \"—\" in FONT_MEDIUM, lock chip \"—\", empty ring track."],
      notes: REACH.concat([{ flag: "(a) Find my car, Status and Settings end up behind More on first launch." }]) },
    { id: "home-sent", section: "home", order: ord("home-sent"), name: "Home, after a command",
      neu: [A(dc => NH.grid(dc, { msg: { text: "Sent", kind: "sent" } })), B(dc => NH.hero(dc, { msg: { text: "Sent", kind: "sent" } }))],
      fixes: ["A12", "A21", "B3"],
      changed: ["\"Sent\" in white with a green check icon; green is never text.", "Focus stays on the tile or row that fired (A12).",
        "Errors use red with \"!\" in the same line (see Home, phone offline)."],
      notes: ["The toast carries the full text; the status line keeps one short word.", "(b) status line max 100 px, (a) max 142 px."] },
    { id: "home-toast", section: "home", order: ord("home-toast"), name: "Toast",
      neu: [Object.assign(A(toastOn(dc => NH.grid(dc, { msg: { text: "Sent", kind: "sent" } }))), { fitcheck: false }), Object.assign(B(toastOn(dc => NH.hero(dc, { msg: { text: "Sent", kind: "sent" } }))), { fitcheck: false })],
      fixes: ["B4"], changed: ["Native toast (device file layout) over the NEW home; nothing custom."],
      notes: ["Garmin draws the toast; the app only chooses text and icon.", "200 ms vibration unchanged.",
        { flag: "Not fitchecked: the toast's grey rule at y 124 crosses what is underneath it, the tile labels in (a) and the focus pill in (b) (Garmin's layout, not ours)." }] },
    { id: "home-more", section: "home", order: ord("home-more"), name: "More menu",
      neu: [{ label: "a · grid", decision: "D1", fitcheck: true, keys: { START: "Open", BACK: "Back to tiles" },
        draw: dc => Ui.menu(dc, { title: "More", items: NH.moreItems(NH.TILES_UNKNOWN).map(l => ({ label: l, icon: NH.ICON[l] })), focus: 0 }) }],
      fixes: ["A14", "D1"], changed: ["Labels without \"\\n\" (A14).", "Icons pin, list and gear.", "Menu pops before the action runs (A14)."],
      notes: ["Only (a) has a More menu, and only above 8 tiles (first launch).", "(b) has no More menu: every action is a row." ] }
  );
  // New-only states
  CARDS.push(
    { id: "home-list-row3", section: "home", order: 150, name: "Home (b), focus on row 4",
      neu: [B(dc => NH.hero(dc, { focus: 3 }))], fixes: ["C1b", "D1"],
      changed: ["Focus on \"Stop charging\": summary on top, two previous rows above, two next rows below."],
      notes: ["Row labels are fitted to the chord at their y with a 12 px ring margin.", REACH[1]] },
    { id: "home-stale", section: "home", order: 151, name: "Home, data 17 h old",
      neu: [A(dc => NH.grid(dc, { ageMin: 17 * 60 })), B(dc => NH.hero(dc, { ageMin: 17 * 60 }))], fixes: ["B1", "B3", "A17"],
      changed: ["Stale age in amber tiny \"! 17 h\" in the status line (amends US-009 red)."],
      notes: ["Short form keeps the line within the (b) 100 px budget."] },
    { id: "home-error", section: "home", order: 152, name: "Home, phone offline",
      neu: [A(dc => NH.grid(dc, { msg: { text: "Phone not connected", kind: "error" } })), B(dc => NH.hero(dc, { msg: { text: "Phone not connected", kind: "error" } }))],
      fixes: ["A21", "B3"], changed: ["Error in red with \"!\" in the status line; full text in the toast."],
      notes: ["Same line as \"Sent\", so command feedback always lands in one place."] },
    { id: "home-trunk", section: "home", order: 153, name: "Home, trunk open",
      neu: [A(dc => NH.grid(dc, { strip: Object.assign(NH.mockStrip(), { lock: "TRUNK_OPENED" }) })),
            B(dc => NH.hero(dc, { strip: Object.assign(NH.mockStrip(), { lock: "TRUNK_OPENED" }) }))],
      fixes: ["A9", "A21", "B3"], changed: ["Lock state becomes an amber chip \"! Trunk open\" (shape plus colour)."],
      notes: ["Unlocked and open use the same amber chip; Locked stays a plain padlock."] }
  );

  // Sample card (lead): the confirmation is Garmin's own; the NEW text keeps it a yes/no question.
  CARDS.push({ id: "home-confirm", section: "home", name: "Confirmation",
    neu: [{ label: "", draw: dc => Native.confirmation(dc, "Stop charging?"), keys: { START: "Yes, send", DOWN: "No" } }],
    fixes: ["B6"], changed: ["Drawn from the device files: green check at START, red cross at DOWN (personality.mss)."], notes: [] });
  window.NH = NH;
})();
