// ================================================================ NEW home (agent B)
// D1 variants: (a) grid per C1a, (b) hero + action list per C1b. Both expose Charging with buttons.
(function () {
  const NH = {};

  // ---------------------------------------------------------------- data
  // Default tile order since 1.3.0 (TileOrder.defaultOrder(); decisions.md "Home opens on its first row"):
  // Status, Find my car, climate, charging, Charging detail, Settings. Home opens on row 0, Status.
  NH.TILES = ["Status", "Find my car", "Start climate", "Stop climate", "Start charging", "Stop charging", "Charging", "Settings"];
  // First launch: operations unknown, so every action is offered (ventilation included).
  NH.TILES_UNKNOWN = ["Status", "Find my car", "Start climate", "Stop climate", "Start ventilation", "Stop ventilation", "Start charging", "Stop charging", "Charging", "Settings"];
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
  // Mirrors app/source/ui/HomeMenu.mc + HomeHero.mc: a CustomMenu with rows of ROW_H under the list
  // mask (Ui.menuMask), so the focused row and its two neighbours are in view, the hero in the 98 px
  // title area above row 0 (it slides out under the mask going to row 1 and back in coming back to
  // row 0), laid out bottom-up: status line, chips, then the SoC in the largest
  // font whose digits clear y 12 and fit the chord (HomeHero.HeroFit). o.shift: see Ui.menu.
  NH.ROW_H = Ui.ROW_H;
  NH.HERO_BOTTOM = 130 - Math.floor(NH.ROW_H / 2);
  NH.hero = function (dc, o = {}) {
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const rows = o.rows || NH.TILES, f = Math.max(0, Math.min(rows.length - 1, o.focus || 0)), s = o.strip || NH.mockStrip();
    const H = NH.ROW_H, shift = o.shift || 0, heroDy = Math.round(-f * H + shift), mask = Ui.menuMask(f);
    if (NH.HERO_BOTTOM + heroDy > mask[0] + 1) {
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
    // Rows: centre y = 130 + (i - f) * H, under the mask. While o.shift is set they slide into place,
    // and the hero and the row leaving slide out under the mask (see Ui.menu).
    for (let i = Math.max(0, f - 2); i <= Math.min(rows.length - 1, f + 2); i++) {
      const cy = Math.round(130 + (i - f) * H + shift);
      if (cy + H / 2 <= mask[0] + 1 || cy - H / 2 >= mask[1] - 1) continue;
      if (i === f) Ui.focusPill(dc, 24, cy - 25, 212, 51, rows[i], "medium");
      else {
        const at = 130 + (i - f) * H, w = Ui.usable(at - 14, at + 15, 8);   // fitted where it settles, as in the app
        dc.setColor(T.TEXT_2); dc.drawText(130, cy, "tiny", Ui.fit(dc, rows[i], "tiny", Math.min(193, w)), J.CENTER | J.VCENTER);
      }
    }
    Ui.drawMenuMask(dc, mask);
    Ui.drawRing(dc, s.soc == null ? 0 : s.soc / 100, { fill: s.charging === "CHARGING" ? T.ACCENT : T.TEXT_1 });
  };

  // ---------------------------------------------------------------- cards
  const KEYS_A = { START: "Run focused tile", "UP/DOWN": "Move tile focus (no wrap)", "Swipe up/down": "Scroll one row", Tap: "Run tile", BACK: "Exit app" };
  const KEYS_B = { START: "Run focused row", "UP/DOWN": "Previous / next row, wrapping at both ends", "Swipe": "Move focus", Tap: "Run row", BACK: "Exit app" };
  const A = (draw, keys = KEYS_A) => ({ label: "a · grid", draw, keys, decision: "D1", fitcheck: true });
  const B = (draw, keys = KEYS_B) => ({ label: "b · hero list", draw, keys, decision: "D1", fitcheck: true });
  const ord = id => OLD_SCREENS[id] ? OLD_SCREENS[id].order : undefined;
  const REACH = [
    "How Charging and Status are reached: (a) the Status tile (row 1, focused when home opens) and the Charging tile (row 4); UP/DOWN move the focus, as verified on the watch.",
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
        "(b) SoC ring, hero \"100%\", chips and the age in the title area, the focused row as accent pill, one row below (rows of 65 px; every row is drawn and a mask covers all but the focused row and its neighbours, so three sit close together and the rest slides in and out under the mask)."],
      notes: REACH.concat(["Default order since 1.3.0: Status, Find my car, then the commands; home opens on Status, so the hero is in view and a stray START opens a screen instead of sending a command.",
        "Mock: 8 tiles fill four rows, so no More. Rule chosen: up to 8 tiles shown as is, above 8 the first 7 plus More.",
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
      changed: ["Unknown SoC and lock show \"—\" (no number-font letters).", "(a) 10 tiles: first 7 plus More; Charging is behind More.",
        "(b) No cap: all 10 rows, including ventilation.", "(b) Hero \"—\" in FONT_MEDIUM, lock chip \"—\", empty ring track."],
      notes: REACH.concat([{ flag: "(a) Stop charging, Charging and Settings end up behind More on first launch." }]) },
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
      changed: ["Focus on \"Stop climate\": the hero has scrolled away; the previous and next rows above and below the pill."],
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

  // ---------------------------------------------------------------- command confirmation (US-062)
  // Mirrors app/source/ui/CommandConfirm.mc: a NightMenu whose title area runs down to row 0, as home's
  // hero does, holding the question in accent tiny: one line where it fits, else two, else two in xtiny (the
  // second cut with "…" only then), 12 px from the outline, the last line NH.CONFIRM_GAP above the rule. Rows: the action, focused on open, then "Cancel".
  // o: {question, action, stop, focus, shift}; stop: the action pill in DESTRUCTIVE (CommandConfirm.isStop).
  NH.CONFIRM_GAP = 6;
  NH.confirm = function (dc, o = {}) {
    const q = o.question || "Stop charging?", focus = o.focus || 0;
    const action = o.action || "Stop charging", stop = o.stop != null ? o.stop : /^Stop /.test(action);
    Ui.menu(dc, { items: [{ label: action, pill: stop ? T.DESTRUCTIVE : null }, { label: "Cancel" }], focus, shift: o.shift });
    if (focus !== 0) return;
    const hb = 130 - Math.floor(Ui.ROW_H / 2), bottom = hb - NH.CONFIRM_GAP;
    const widths = f => { const h = FM[f].h; return [Ui.usable(bottom - 2 * h, bottom - h, 12), Ui.usable(bottom - h, bottom, 12)]; };
    let font = "tiny", lines = dc.getTextWidthInPixels(q, "tiny") <= widths("tiny")[1] ? [q] : TB.wrap(q, widths("tiny"), s => dc.getTextWidthInPixels(s, "tiny"));
    if (lines.length > 2) { font = "xtiny"; lines = Ui.wrap(dc, q, "xtiny", widths("xtiny"), 2); }
    dc.setColor(T.ACCENT); lines.forEach((l, i) => dc.drawText(130, bottom - (lines.length - i) * FM[font].h, font, l, J.CENTER));
    dc.setColor(T.RULE); dc.fillRectangle(60, hb - 2, 140, 1);
  };
  const CONFIRM_KEYS = { START: "Picks the focused row: the action on open (not in its first 0.5 s)", "UP/DOWN": "Move between the action and Cancel", Tap: "Picks the row tapped", BACK: "Cancel, nothing sent" };
  CARDS.push({ id: "home-confirm", section: "home", name: "Confirmation",
    neu: [{ label: "Opens on the action", draw: dc => NH.confirm(dc, {}), keys: CONFIRM_KEYS, fitcheck: true },
      { label: "After DOWN", draw: dc => NH.confirm(dc, { focus: 1 }), keys: { START: "Cancel, nothing sent", UP: "Back to the action", BACK: "Cancel, nothing sent" }, fitcheck: true },
      { label: "Two lines", draw: dc => NH.confirm(dc, { question: "Start the auxiliary heater?", action: "Start aux heat" }), keys: CONFIRM_KEYS, fitcheck: true },
      { label: "With a value", draw: dc => NH.confirm(dc, { question: "Set mode to Immediate discharging?", action: "Set mode" }), keys: CONFIRM_KEYS, fitcheck: true },
      { label: "A start", draw: dc => NH.confirm(dc, { question: "Start climate?", action: "Start climate" }), keys: CONFIRM_KEYS, fitcheck: true }],
    fixes: ["B6"],
    changed: ["Every command asks first (US-062), on a NightMenu instead of Garmin's Confirmation: the question in the title area, the action focused, \"Cancel\" below it.",
      "With \"Confirm commands\" off (Garmin Connect, or Settings on the watch) nothing asks: no exception for stop charging, the auxiliary heater or a low quota.",
      "The question wraps to two lines where one does not fit; the action row uses the home row's words, and the charge limit and mode keep their value in the question."],
    notes: ["The action is row 0 so the question stays in view: from row 1 on the mask covers the title on the button watches. Confirming is one more press of the same button.",
      "A second START, or a second tap where home's focused row was, lands on the action, so it ignores a pick in the first 0.5 s after the screen opens: a double tap or double press sends nothing. Someone who keeps pressing confirms with the first press after that. Not measured on a watch.",
      "A tap where home's row above the focus was lands on the question and does nothing; where the row below was, on Cancel.",
      "BACK always cancels. Pushed and popped with SLIDE_IMMEDIATE (Theme.SLIDE_DIALOG).",
      "Stop commands (climate, ventilation, aux heat, charging) get a red action pill, without the \"!\" red carries elsewhere: \"!\" means a failure or warning, and the word Stop says it. Starts, the charge limit and the charge mode keep the accent. Monochrome: white, as every pill.",
      "Clear stored data and Navigate keep Garmin's confirmation (they are not commands)."] });
  window.NH = NH;
})();
