// ================================================================ DEVICES: screens
// The catalogue: every screen with its drawing for today (the poc's NEW draw, corrected where the poc
// drifts from app 1.1.x) and its proposal on each watch. Proposals are drawn by DS.* below, which lay
// screens out from the Dc: y positions stack from the measured font heights, widths come from the outline
// at that y (G.usable), bezel parts sit at R - k·s (G.*). On the fēnix these rules reproduce today's
// numbers (Status 34/64/142/192/212, Charging 58/134/160/202), so the fēnix column shows what changes
// in behaviour, not in pixels.
//
// Entry fields: id, section, name, src, today(dc), prop(dc, G, P), avail(P), indicator (C watches show
// Garmin's action menu indicator and route MENU through onActionMenu), raw (draw at device px), bg,
// fenix ("same" | "changed"), kind ("scaled" | "adapted"), todayKeys, intents(P), notes {today, A, A0, B, C, X1
// (rectangle), noMap, <column id>, all}. Notes never list watches by hand: a layout outcome that differs per
// watch is returned by its DS.* draw and shown as a row of the watch table (50-board.js), and a list of watches
// with some property is written with DEV.namesWhere, so both follow the manifest.
const DEV_SCREENS = (function () {
  const DS = {};
  const blank = dc => { dc.setColor(T.TEXT_1, T.BG); dc.clear(); };
  const TITLES = NS.titles;

  // ------------------------------------------------------------ shared pieces
  // Detail lines in xtiny; a line that would pass maxBottom (the age line) is dropped, last first (M14).
  function lines(dc, G, y0, pitch, list, color, margin = 12, maxBottom = Infinity) {
    const keep = list.filter((s, i) => y0 + i * pitch + FM.xtiny.h <= maxBottom);
    keep.forEach((s, i) => { const y = y0 + i * pitch; dc.setColor(color || T.TEXT_1); dc.drawText(130, y, "xtiny", Ui.fit(dc, s, "xtiny", G.usable(y, y + FM.xtiny.h, margin)), J.CENTER); });
    return y0 + keep.length * pitch;
  }
  // Number hero in the watch's hero font (M1); steps down to numMild + small unit when it outgrows the outline.
  function valueHero(dc, G, top, value, unit, o = {}) {
    let num = G.heroFont, uf = G.unitFont;
    const width = (n, u) => dc.getTextWidthInPixels(value, n) + (unit ? (o.gap == null ? 4 : o.gap) + dc.getTextWidthInPixels(unit, u) : 0);
    if (width(num, uf) > G.usable(top, top + FM[num].h, 12)) { num = "numMild"; uf = "small"; }
    if (width(num, uf) > G.usable(top, top + FM[num].h, 12)) { num = "medium"; uf = "small"; }   // large user font: digits in the text font
    Ui.drawValueWithUnit(dc, 130, top, value, unit, { num, unitFont: uf, gap: o.gap });
    return top + FM[num].h;
  }
  function heroValueIcon(dc, G, top, value, icon) {
    const f = G.heroFont, wv = dc.getTextWidthInPixels(value, f), iw = 26, total = wv + 8 + iw, x0 = Math.round(130 - total / 2);
    dc.setColor(T.TEXT_1); dc.drawText(x0, top, f, value, J.LEFT);
    NIcons.draw(dc, icon, x0 + wv + 8 + 13, top + Math.round(FM[f].asc * 0.62), 12, T.TEXT_1);
    return top + FM[f].h;
  }
  // Lock grid chip: outline (or warning fill), check or bang icon, label. The width is sized for label + 30
  // (icon 12, gap 4, 7 each side); where the width is capped the label may use 3 px of each side before "…".
  function gridChip(dc, x, y, w, h, c) {
    const warn = c.kind === "warn", fg = warn ? T.BLACK : T.TEXT_1;
    if (warn) { dc.setColor(T.WARNING); dc.fillRoundedRectangle(x, y, w, h, h / 2); }
    else { dc.setColor(T.RULE); dc.setPenWidth(1); dc.drawRoundedRectangle(x, y, w, h, h / 2); }
    const text = Ui.fit(dc, c.text, "xtiny", w - 24), tw = dc.getTextWidthInPixels(text, "xtiny"), cw = c.more ? tw : 12 + 4 + tw, x0 = Math.round(x + (w - cw) / 2);
    if (!c.more) NIcons.draw(dc, warn ? "bang" : "check", x0 + 6, y + h / 2, 6, fg);
    dc.setColor(fg); dc.drawText(c.more ? x0 : x0 + 16, y + Math.round(h / 2), "xtiny", text, J.LEFT | J.VCENTER);
  }
  function lockItems(o) {
    const raw = { doors: NMOCK.doors, windows: NMOCK.windows, bonnet: NMOCK.bonnet, trunk: o.trunkOpen ? "OPEN" : NMOCK.trunk, lights: NMOCK.lights, sunroof: NMOCK.sunroof };
    const names = { doors: "Doors", windows: "Windows", bonnet: "Bonnet", trunk: "Trunk", lights: "Lights", sunroof: "Sunroof" };
    const items = Object.keys(names).filter(k => raw[k] !== "UNSUPPORTED").map(k => ({ text: names[k], kind: raw[k] === "OPEN" ? "warn" : "outline" }));
    return items.filter(i => i.kind === "warn").concat(items.filter(i => i.kind !== "warn"));
  }
  // M12 lock grid. Chip width fits the longest label (89 on the fēnix), capped by the width of the paired rows
  // (a lone last chip sits centred under them). The indicator keep-out only limits the right edge, so the grid
  // may shift left. When three rows do not fit above the age, squeeze in order: word to grid gap 9 → 4, row gap
  // 2 → 1, age clearance 3 → 1; only then two rows and "+N" (open items sort first, so none hides behind it).
  const SQUEEZE = [[9, 2, 3], [4, 2, 3], [4, 1, 3], [4, 1, 1]];
  function lockGrid(dc, G, wordTop, ageTop, all, wordFont = "medium") {
    const Hc = FM.xtiny.h + 3, longest = Math.ceil(Math.max(...all.map(c => dc.getTextWidthInPixels(c.text, "xtiny"))));
    const layout = (items, [gap, rowGap, clear]) => {
      const n = Math.min(6, items.length), rows = Math.ceil(n / 2), first = wordTop + FM[wordFont].h + gap, pitch = Hc + rowGap;
      const pairRows = Math.max(1, Math.floor(n / 2)), [l, r] = G.span(first, first + (pairRows - 1) * pitch + Hc, 12);
      const W = Math.min(Math.max(89, longest + 30), Math.floor((r - l - 6) / 2)), gridW = 2 * W + 6;
      return { items: items.slice(0, n), Hc, first, pitch, W, gridW, x0: Math.round(Math.min(130 - gridW / 2, r - gridW)), fits: first + (rows - 1) * pitch + Hc <= ageTop - clear };
    };
    const tryAll = items => { for (let i = 0; i < SQUEEZE.length; i++) { const t = layout(items, SQUEEZE[i]); if (t.fits) return Object.assign(t, { step: i }); } return null; };
    const more = all.length > 4 ? all.slice(0, 3).concat([{ text: "+" + (all.length - 3), more: true }]) : all.slice(0, 4);
    const one = all.length > 2 ? [all[0], { text: "+" + (all.length - 1), more: true }] : all;   // large user font only (M14)
    return tryAll(all) || tryAll(more) || tryAll(one) || layout(one, SQUEEZE[SQUEEZE.length - 1]);
  }
  const menuGlyph = dc => Ui.drawBezelGlyph(dc, "start", "menu", T.TEXT_1, "accent");
  // SG §5: a title that needs more room moves down rather than shrinking (at most 20 px, then "…").
  function title(dc, G, text, y) {
    const tw = dc.getTextWidthInPixels(text, "tiny"); let t = y;
    while (t < y + 20 && tw > G.usable(t, t + FM.tiny.h)) t += 2;
    if (tw <= G.usable(t, t + FM.tiny.h)) Ui.title(dc, text, t);
    else { dc.setColor(T.ACCENT); dc.drawText(130, t, "tiny", Ui.fit(dc, text, "tiny", G.usable(t, t + FM.tiny.h, 12)), J.CENTER); }   // "…" inside the 12 px edge
    return t;
  }

  // ------------------------------------------------------------ home (HomeMenu + HomeHero, from the Dc)
  function statusLine(dc, y, o, maxW) {
    const m = o.msg;
    if (m && m.kind === "sent") {
      const t = Ui.fit(dc, m.text || "Sent", "xtiny", maxW - 16), w = dc.getTextWidthInPixels(t, "xtiny") + 16, x0 = Math.round(130 - w / 2);
      NIcons.draw(dc, "check", x0 + 6, y + FM.xtiny.h / 2, 6, T.POSITIVE); dc.setColor(T.TEXT_1); dc.drawText(x0 + 16, y, "xtiny", t, J.LEFT);
    } else if (m && m.kind === "error") { dc.setColor(T.DESTRUCTIVE); dc.drawText(130, y, "xtiny", Ui.fit(dc, "! " + m.text, "xtiny", maxW), J.CENTER); }
    else { const min = o.ageMin == null ? NMOCK.ageMin : o.ageMin; Ui.drawAge(dc, y, min, Age.stale(min) ? { short: true } : {}); }
  }
  // Default home order since 1.3.0 (decisions.md "Home opens on its first row."): Status, Find my car,
  // then the commands with the primary action first, Charging and Settings. Home opens on row 0.
  const HOME_ROWS = NH.TILES;
  // The order up to 1.2, for the "today" column: climate first, so home opened on "Start climate".
  const TODAY_ROWS = ["Start climate", "Stop climate", "Start charging", "Stop charging", "Charging", "Find my car", "Status", "Settings"];
  DS.home = function (dc, G, o = {}) {
    blank(dc);
    const rows = o.rows || HOME_ROWS, f = Math.max(0, Math.min(rows.length - 1, o.focus || 0)), s = NH.mockStrip(), H = Ui.ROW_H, out = {};
    const heroBottom = 130 - Math.floor(H / 2);
    if (f === 0) {
      const statusTop = heroBottom - FM.xtiny.h, chipH = G.chipH();
      const chips = [{ icon: "locked", text: Labels.lock(s.lock) }, { icon: "pluggedIn", text: Labels.charging(s.charging) }];
      const chipsTop = statusTop - 2 - chipH;
      statusLine(dc, statusTop, o, G.usable(statusTop, statusTop + FM.xtiny.h, 12));
      const maxW = G.usable(chipsTop, chipsTop + chipH, 12); let keep = chips.length;
      const widthOf = n => chips.slice(0, n).reduce((a, c) => a + Ui.chipWidth(dc, c), 0) + 6 * (n - 1);
      while (keep > 0 && widthOf(keep) > maxW) keep--;
      // SoC number: the largest font whose digit top stays below MIN_DIGIT_TOP and fits the outline. At a large
      // user font size the chips give way when no font fits above them, and then the number (the ring shows the SoC) (M14).
      const value = String(s.soc), unitW = dc.getTextWidthInPixels("%", "small") + 4;
      const pick = baseline => { for (const fnt of ["numMed", "numMild", "medium"]) {
        const top = baseline - Math.floor((FM[fnt].asc * 4 + 4) / 5);
        if (top >= G.minDigitTop && dc.getTextWidthInPixels(value, fnt) + unitW <= G.usable(top, baseline, 12)) return fnt;
      } return null; };
      let baseline = chipsTop - 4, font = pick(baseline);
      if (!font) { keep = 0; baseline = statusTop - 4; font = pick(baseline); }
      if (keep) Ui.drawChipRow(dc, chipsTop, chips.slice(0, keep).map(c => Object.assign({ h: chipH }, c)));
      if (font) Ui.drawValueWithUnit(dc, 130, baseline - FM[font].asc, value, "%", { num: font, unitFont: "small" });
      out.chips = keep; out.socFont = font;
    }
    for (let i = Math.max(0, f - 1); i <= Math.min(rows.length - 1, f + 1); i++) {
      const cy = Math.round(130 + (i - f) * H);
      if (i === f) { const ph = Math.min(FM.medium.h + 14, H - 6); Ui.focusPill(dc, 24, Math.round(cy - ph / 2), 212, ph, rows[i], "medium"); }
      else { const w = G.usable(cy - FM.tiny.h / 2, cy + FM.tiny.h / 2, 8); dc.setColor(T.TEXT_2); dc.drawText(130, cy, "tiny", Ui.fit(dc, rows[i], "tiny", Math.min(193, w)), J.CENTER | J.VCENTER); }
    }
    Ui.drawRing(dc, s.soc / 100, { fill: s.charging === "CHARGING" ? T.ACCENT : T.TEXT_1 });
    return out;   // layout outcome on the hero: chips kept (of 2), SoC font
  };

  // ------------------------------------------------------------ status pages
  // copy: "today" keeps the button-naming empty state, anything else the button-neutral one (M7).
  DS.status = function (dc, G, o = {}) {
    const page = o.page || "lock", idx = NS.pages.indexOf(page), out = {};
    blank(dc);
    const tTop = title(dc, G, TITLES[page], G.Tt);
    const statusTop = G.statusTop(), ageTop = statusTop - FM.xtiny.h - 1, age = o.ageMin != null ? o.ageMin : page === "lock" ? NMOCK.statusAgeMin : NMOCK.ageMin;
    const valueTop = tTop + FM.tiny.h + 1, wordTop = tTop + FM.tiny.h + 7;
    if (o.nodata) {
      dc.setColor(T.TEXT_1); dc.drawText(130, 130 - 32, "small", "No data yet", J.CENTER);
      dc.setColor(T.TEXT_2); dc.drawText(130, 130 + 6, "xtiny", Ui.fit(dc, o.copy === "today" ? "START to refresh" : "Refresh from the menu", "xtiny", G.usable(136, 136 + FM.xtiny.h, 12)), J.CENTER);
    } else if (page === "lock") {
      const raw = o.trunkOpen ? "TRUNK_OPENED" : NMOCK.lock;
      // Hero word in medium; at a large user font size it steps down to small when not even one chip row fits (M14).
      let wf = "medium", L = lockGrid(dc, G, wordTop, ageTop, lockItems(o), wf);
      if (!L.fits) { wf = "small"; L = lockGrid(dc, G, wordTop, ageTop, lockItems(o), wf); }
      out.lock = { step: L.step, rows: Math.ceil(L.items.length / 2), more: L.items.some(c => c.more), word: wf };
      Ui.drawHero(dc, { word: Labels.lock(raw), icon: Icons.forLock(raw), y: wordTop, font: wf, color: raw !== "YES" ? T.WARNING : T.TEXT_1 });
      L.items.forEach((c, i) => {
        const row = Math.floor(i / 2), alone = i === L.items.length - 1 && i % 2 === 0;
        gridChip(dc, alone ? Math.round(L.x0 + (L.gridW - L.W) / 2) : L.x0 + (i % 2) * (L.W + 6), L.first + row * L.pitch, L.W, L.Hc, c);
      });
      Ui.drawAge(dc, ageTop, age);
    } else if (page === "fuel") {
      const b = valueHero(dc, G, valueTop, String(NMOCK.totalRange), "km");
      lines(dc, G, b + 4, FM.xtiny.h + 1, [Labels.engine(NMOCK.primary.engine) + " " + NMOCK.primary.pct + "%", Labels.engine(NMOCK.secondary.engine) + " " + NMOCK.secondary.pct + "%"], null, 12, ageTop - 2);
      Ui.drawAge(dc, ageTop, age);
    } else if (page === "charging") {
      const b = heroValueIcon(dc, G, valueTop, NMOCK.soc + "%", Icons.forCharging(NMOCK.charging) || "pluggedIn");
      lines(dc, G, b + 4, FM.xtiny.h + 1, [Labels.charging(NMOCK.charging), NMOCK.rangeKm + " km range"], null, 12, ageTop - 2);
      Ui.drawAge(dc, ageTop, age);
    } else if (page === "odo") {
      valueHero(dc, G, valueTop, String(NMOCK.odometer), "km", { gap: 3 });
      Ui.drawAge(dc, ageTop, age);
    } else if (page === "ac") {
      const on = NMOCK.climate !== "OFF";
      Ui.drawHero(dc, { word: Labels.climate(NMOCK.climate), icon: on ? "climate" : "fan", y: wordTop });
      lines(dc, G, wordTop + FM.medium.h + 21, FM.xtiny.h + 1, ["Windscreen heat " + Labels.state(NMOCK.heatFront).toLowerCase(), "Rear window heat " + Labels.state(NMOCK.heatRear).toLowerCase()], null, 12, ageTop - 2);
      Ui.drawAge(dc, ageTop, age);
    }
    G.dots(dc, idx, NS.pages.length);
    menuGlyph(dc);
    return out;   // layout outcome: the lock grid's squeeze step, rows and "+N"
  };

  // ------------------------------------------------------------ charging detail
  DS.charging = function (dc, G, o = {}) {
    const ex = o.example ? { soc: 80, charging: "CHARGING", rows: ["7.2 kW · AC", "Full by 18:40 (95 min)"], age: 3 } : null;
    const soc = ex ? ex.soc : NMOCK.soc, raw = o.cable ? "CONNECT_CABLE" : ex ? ex.charging : NMOCK.charging, active = raw === "CHARGING";
    blank(dc);
    Ui.drawRing(dc, soc / 100, { fill: active ? T.ACCENT : T.TEXT_1, tick: o.limit != null ? o.limit / 100 : null });
    const heroTop = title(dc, G, "Charging", G.Tt) + FM.tiny.h - 5;
    let f = G.heroFont; if (dc.getTextWidthInPixels(soc + "%", f) > G.usable(heroTop, heroTop + FM[f].h, 12)) f = "numMild";
    Ui.drawValueWithUnit(dc, 130, heroTop, soc + "%", null, { num: f });
    const chipTop = heroTop + FM[f].h + 2, chipH = G.chipH();
    Ui.drawChip(dc, 130, chipTop, o.cable ? { text: Labels.charging(raw), kind: "warn" } : { text: Labels.charging(raw), icon: active ? "bolt" : "pluggedIn" });
    const ageTop = (G.round ? 260 - 39 : G.bottom - 30) - FM.xtiny.h;
    lines(dc, G, chipTop + chipH + 5, FM.xtiny.h + 1, ex ? ex.rows : [NMOCK.rangeKm + " km range"], null, 12, ageTop - 2);
    Ui.drawAge(dc, ageTop, ex ? ex.age : o.cable ? 5 : NMOCK.ageMin);
    Ui.drawBezelGlyph(dc, "start", "menu", T.TEXT_1, false);
  };

  // ------------------------------------------------------------ charging profiles
  DS.profile = function (dc, G) {
    blank(dc);
    const tTop = title(dc, G, "Charging profiles", G.Tt + 6);
    const nameTop = tTop + FM.tiny.h + 1; Ui.drawHero(dc, { word: "Home", y: nameTop });
    const chipTop = nameTop + FM.medium.h + 1, chipH = G.chipH(); Ui.drawChip(dc, 130, chipTop, { text: "Here", kind: "white", icon: "pin" });
    const factsTop = chipTop + chipH + 7, factsEnd = lines(dc, G, factsTop, FM.xtiny.h, ["Target 80%", "Max current reduced"]);
    const last = (G.round ? 260 : G.bottom) - 44, timers = ["22:00 Mon-Fri", "07:30 Sat, Sun"].filter((t, i) => factsEnd + 4 + i * FM.xtiny.h <= last);
    lines(dc, G, factsEnd + 4, FM.xtiny.h, timers, T.TEXT_2);
    G.dots(dc, 0, 2);
  };
  DS.profilesUnsupported = function (dc, G) {
    blank(dc); title(dc, G, "Charging profiles", G.Tt + 6);
    dc.setColor(T.TEXT_1); dc.drawText(130, 130 - 26, "small", "Not supported", J.CENTER);
    dc.setColor(T.TEXT_2); dc.drawText(130, 130 + 6, "small", "by this car", J.CENTER);
  };

  // ------------------------------------------------------------ find my car
  const EXF = { dist: "240", unit: "m", bearing: 35 };
  // Address widths: round = chord of the track's text radius (FindCarLayout.chordWidth), rectangle = usable.
  // Where START shows the menu glyph (no map), a line level with it also keeps 4 px clear of the glyph box.
  function address(dc, G, y0, color = T.TEXT_1) {
    const h = FM.xtiny.h, glyph = !G.P.map && "start" in G.P.btn ? G.anchor("start") : null;
    const width = (t, b) => { const w = G.trackWidth(t, b); return glyph && b > glyph[1] - 6 && t < glyph[1] + 6 ? Math.min(w, 2 * (glyph[0] - 6 - 4 - 130)) : w; };
    const widths = [width(y0, y0 + h), width(y0 + h, y0 + 2 * h)];
    const ls = Ui.wrap(dc, NMOCK.address, "xtiny", widths, 2);
    dc.setColor(color); ls.forEach((l, i) => dc.drawText(130, y0 + i * h, "xtiny", l, J.CENTER));
    return y0 + 2 * h;
  }
  const addrTop = G => G.round ? 46 : G.top + 32;
  // START: the map when parked and the watch has MapView, otherwise the Find my car list (M4).
  function fcStart(dc, G, parked) {
    if (parked && G.P.map) { Ui.drawHintArc(dc, "start", "accent"); if (G.P.five) Ui.drawBezelGlyph(dc, "up", "menu", T.TEXT_2, false); }
    else menuGlyph(dc);
  }
  DS.fcParked = function (dc, G, o = {}) {
    blank(dc); NF.ring(dc);
    const b = address(dc, G, addrTop(G));
    valueHero(dc, G, b + 4, EXF.dist, EXF.unit);
    Ui.drawAge(dc, b + 4 + FM[G.heroFont].h + 10, NMOCK.ageMin);   // anchored on the watch's hero font, also when the number steps down
    NF.pointer(dc, EXF.bearing, o.heading !== false);
    fcStart(dc, G, true);
  };
  DS.fcGps = function (dc, G) {
    blank(dc); NF.ring(dc);
    const b = address(dc, G, addrTop(G));
    const gf = fitFont(dc, G, "Waiting for GPS", ["small", "tiny", "xtiny"], f => Math.round(130 - FM[f].h / 2 - 2));
    dc.setColor(T.TEXT_2); dc.drawText(130, gf.y, gf.f, gf.text, J.CENTER);   // small at 112 on the fēnix
    Ui.drawAge(dc, Math.max(b + FM.small.h + 30, Math.round(130 + FM.small.h / 2 + 26)), NMOCK.ageMin);
    fcStart(dc, G, true);
  };
  // Hero at cy − 40, "Last parked" at cy, address, age (90 / 130 / 150 / 196 on the fēnix). The word steps down
  // medium → small → tiny to fit the track; if the age would pass the status line, the block moves up (M14).
  DS.fcMoving = function (dc, G) {
    blank(dc); NF.ring(dc);
    const ageLimit = G.round ? 260 - 29 : G.bottom - 20;
    const stack = up => {
      const hf = fitFont(dc, G, "Car is moving", ["medium", "small", "tiny"], () => 130 - 40 - up), lp = 130 - up;
      return { hf, lp, addr: lp + FM.xtiny.h + 1, age: lp + FM.xtiny.h + 1 + 2 * FM.xtiny.h + 8 };
    };
    let st = stack(0); const over = st.age + FM.xtiny.h - ageLimit;
    if (over > 0) st = stack(Math.min(over, 130 - 40 - G.Tt));
    Ui.drawHero(dc, { word: st.hf.text, y: st.hf.y, font: st.hf.f });
    dc.setColor(T.TEXT_2); dc.drawText(130, st.lp, "xtiny", "Last parked", J.CENTER);
    const b = address(dc, G, st.addr);
    Ui.drawAge(dc, b + 8, NMOCK.ageMin);
    menuGlyph(dc);
  };
  // The first font of `fonts` whose line fits the track at its y (yOf(font)); the last one fitted with "…" otherwise.
  function fitFont(dc, G, text, fonts, yOf) {
    for (const f of fonts) { const y = yOf(f); if (dc.getTextWidthInPixels(text, f) <= G.trackWidth(y, y + FM[f].h)) return { f, y, text }; }
    const f = fonts[fonts.length - 1], y = yOf(f);
    return { f, y, text: Ui.fit(dc, text, f, G.trackWidth(y, y + FM[f].h)) };
  }
  // Message states (no data, unavailable): lines centred on cy - 6, hint line grey.
  DS.fcMessage = function (dc, G, msgLines, hint, o = {}) {
    blank(dc); NF.ring(dc);
    // small → tiny → xtiny on one line each; at a large user font size, xtiny lines wrap inside the track (M14).
    const src = msgLines.map(t => ({ t, hint: false })).concat(hint ? [{ t: hint, hint: true }] : []);
    const at = (n, lh, i) => Math.round(130 - 6 - n * lh / 2) + i * lh, width = (f, n, i) => Math.min(G.usable(at(n, FM[f].h, i), at(n, FM[f].h, i) + FM[f].h, 16), G.trackWidth(at(n, FM[f].h, i), at(n, FM[f].h, i) + FM[f].h));
    let f = null, all = src;
    for (const fnt of ["small", "tiny", "xtiny"]) if (src.every((l, i) => dc.getTextWidthInPixels(l.t, fnt) <= width(fnt, src.length, i))) { f = fnt; break; }
    if (!f) {
      f = "xtiny";
      for (let pass = 0, n = src.length; pass < 4; pass++) {
        const out = []; for (const l of src) for (const w of TB.wrap(l.t, [width(f, n, out.length)], s => dc.getTextWidthInPixels(s, f))) out.push({ t: w, hint: l.hint });
        all = out; if (out.length === n) break; n = out.length;
      }
      all = all.map((l, i) => ({ t: Ui.fit(dc, l.t, f, width(f, all.length, i)), hint: l.hint }));
    }
    const lh = FM[f].h;
    all.forEach((l, i) => { dc.setColor(l.hint ? T.TEXT_2 : T.TEXT_1); dc.drawText(130, at(all.length, lh, i), f, l.t, J.CENTER); });
    if (o.glyph !== false) menuGlyph(dc);
  };

  // ------------------------------------------------------------ settings, onboarding
  const TEMPS = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30];
  DS.tempList = function (dc) {
    blank(dc);
    Ui.menu(dc, { title: "Temperature", items: TEMPS.map(t => ({ label: t + " °C", check: t === NMOCK.targetTemp })), focus: TEMPS.indexOf(NMOCK.targetTemp) });
  };
  DS.tempListTop = function (dc) {
    blank(dc);
    Ui.menu(dc, { title: "Temperature", items: TEMPS.map(t => ({ label: t + " °C", check: t === NMOCK.targetTemp })), focus: 0 });
  };
  const menu = (title, items, focus = 0) => dc => { blank(dc); Ui.menu(dc, { title, items, focus }); };
  const CH_MENU = [{ label: "Refresh", icon: "refresh" }, { label: "Set charge limit", sub: "80%", icon: "battery" }, { label: "Set charge mode", sub: "Manual", icon: "bolt" }, { label: "Charging profiles", icon: "list" }];
  const FC_MENU = [{ label: "Navigate", icon: "pin" }, { label: "Refresh", icon: "refresh" }];
  const ACTIONS = page => [{ label: "Refresh", icon: "refresh" }].concat(page === "charging" ? [{ label: "Charging details", icon: "bolt" }] : []);
  DS.statusToday = o => dc => NS.page(dc, Object.assign({ indicator: "dots", start: "menu" }, o));

  // ------------------------------------------------------------ onboarding text (OnboardingLayout)
  // As built (OnboardingLayout.choose): FONT_SMALL when the text fits in four lines, else FONT_XTINY, centred,
  // wrapped to the outline with 26 px clear of bezel glyphs (12 without). When even FONT_XTINY runs past the
  // outline (long copy on a large screen, any watch at a large user font size), the most centred xtiny lines that
  // fit are filled and the last ends in "…" (cut: true). Splitting it into parts with page dots is the open
  // proposal M14, not drawn here.
  function obLayout(dc, G, text, margin) {
    const measure = f => s => dc.getTextWidthInPixels(s, f);
    for (const f of ["small", "xtiny"]) {
      // Wrap for n slots centred on cy, n = the line count of the previous pass; accepted as soon as every line
      // fits the outline where it is drawn (the passes may oscillate between two counts).
      const lh = FM[f].h;
      for (let pass = 0, count = 1; pass < 8; pass++) {
        const slots = n => { const top = 130 - Math.floor(n * lh / 2), w = []; for (let i = 0; i < n; i++) w.push(G.usable(top + i * lh, top + (i + 1) * lh, margin)); return { top, w }; };
        const lines = TB.wrap(text, slots(count).w, measure(f)), fin = slots(lines.length);
        const fits = fin.top >= G.minDigitTop && lines.every((l, i) => fin.w[i] >= 40 && measure(f)(l) <= fin.w[i]);
        if (fits && (f === "xtiny" || lines.length <= 4)) return { f, lh, pages: [{ top: fin.top, lines }] };
        if (lines.length === count) break; count = lines.length;
      }
    }
    // OnboardingLayout.maxSlots: the most centred slots whose top clears minDigitTop and whose every line is at
    // least 40 wide, then Ui.wrapFit into them.
    const f = "xtiny", lh = FM[f].h, slotsAt = n => { const top = 130 - Math.floor(n * lh / 2), w = [];
      for (let i = 0; i < n; i++) w.push(G.usable(top + i * lh, top + (i + 1) * lh, margin)); return { top, w }; };
    let n = 1;
    for (let k = 1; k <= Math.floor(260 / lh); k++) { const s = slotsAt(k); if (s.top < G.minDigitTop || s.w.some(w => w < 40)) break; n = k; }
    const s = slotsAt(n);
    return { f, lh, cut: TB.wrap(text, s.w, measure(f)).length > n, pages: [{ top: s.top, lines: Ui.wrap(dc, text, f, s.w, n) }] };
  }
  DS.obText = function (dc, G, text, o = {}) {
    blank(dc);
    const L = obLayout(dc, G, text, o.glyphs ? 26 : 12), page = L.pages[Math.min(o.page || 0, L.pages.length - 1)];
    dc.setColor(T.TEXT_1); page.lines.forEach((l, i) => dc.drawText(130, page.top + i * L.lh, L.f, l, J.CENTER));
    if (L.pages.length > 1) G.dots(dc, o.page || 0, L.pages.length);
    if (o.menu) Ui.drawBezelGlyph(dc, "up", "menu", T.TEXT_1);
    if (o.ok) Ui.drawBezelGlyph(dc, "start", "check", T.ACCENT, "accent");
    return L;
  };

  // ------------------------------------------------------------ intents
  // What each behaviour does on a screen; 45-input.js turns this into the controls per watch.
  const LIST = (select, back = "Close") => ({ select, tap: select, next: "Next row", prev: "Previous row", back });
  const all = () => true, hasMap = P => !!P.map;

  // ------------------------------------------------------------ catalogue
  const S = [];
  const add = (section, e) => S.push(Object.assign({ section, kind: "scaled", fenix: "same", avail: all, notes: {} }, e));

  // entry
  add("entry", { id: "glance-data", name: "Glance, with cached data", src: "ui/GlanceView.mc", raw: true, kind: "adapted",
    today: dc => NG.glance(dc, { data: true }), prop: (dc, G, P) => P.id === "fenix7pro" ? NG.glance(dc, { data: true }) : DevNative.glance(dc, P, { data: true }),
    todayKeys: { START: "Open app", "UP / DOWN": "Next glance" }, intents: () => ({ select: "Open app", tap: "Open app", next: "Next glance", prev: "Previous glance", back: "Watch face" }),
    notes: { today: ["Content area 171 × 63; PAD, row y and the 4 px bar are fixed pixels in GlanceView."],
      all: ["Content area from the device file; rows stack by font height and centre in it, paddings × s."],
      B: ["Glance area 260 × 141 (3S) / 303 × 164 (3): room for a larger SoC; kept to three rows for one design."],
      vivoactive6: ["vívoactive 6 / Venu 4 41 mm differ: 274 × 146 vs 274 × 128. Centring keeps both."], X1: ["Content area 314 × 150."] } });
  add("entry", { id: "glance-empty", name: "Glance, nothing cached", src: "ui/GlanceView.mc", raw: true, kind: "adapted",
    today: dc => NG.glance(dc, { data: false }), prop: (dc, G, P) => P.id === "fenix7pro" ? NG.glance(dc, { data: false }) : DevNative.glance(dc, P, { data: false }),
    todayKeys: { START: "Open app" }, intents: () => ({ select: "Open app", tap: "Open app", back: "Watch face" }), notes: {} });

  // home
  const homeIntents = () => ({ select: "Run the focused row", tap: "Run the row; on the hero: Status", next: "Next row (wraps on buttons)", prev: "Previous row", back: "Leave the app" });
  add("home", { id: "home-mock", name: "Home", src: "ui/HomeMenu.mc, ui/HomeHero.mc", kind: "adapted",
    today: dc => NH.hero(dc, { rows: TODAY_ROWS }), prop: (dc, G) => DS.home(dc, G, {}),
    todayKeys: { START: "Run focused row", "UP / DOWN": "Previous / next row, wrapping", BACK: "Leave the app", Tap: "Row runs it; hero opens Status" }, intents: homeIntents,
    notes: { today: ["Hero title area is HOME_TITLE_H = 98 px; chips fixed at 21 px."],
      all: ["Default order Status, Find my car, then the commands (primary action first); home opens on row 0, so the hero is in view (decisions.md, Home opens on its first row).",
        "Hero area = Theme.heroBottom() from the Dc (cy − rowH/2), chip height = Chips.height() (FONT_XTINY + 2), pill = FONT_MEDIUM + 14, capped at rowH − 6.",
        "No action menu indicator: home is a Menu, and onActionMenu only exists on BehaviorDelegate.",
        "One chip (Locked) instead of two where the chord at the chip row is too narrow for both: the plug chip drops first by design. Which watches keep both: \"Home chips\" in the watch table.",
        "At font size 1.4× the chips give way when no number font fits above them; the ring still shows the SoC (M14)."],
      B: ["No wrap on touch: onWrap only fires for buttons. Status stays reachable by its row and the hero tap."],
      C: ["Same as Venu 3: there is no MENU action on home, so nothing is lost without the MENU key."],
      X1: ["Ring becomes a frame along the display edge, filling clockwise from top centre (M3)."] } });
  add("home", { id: "home-scrolled", name: "Home, scrolled to Settings", src: "ui/HomeMenu.mc", kind: "scaled",
    today: dc => NH.hero(dc, { rows: TODAY_ROWS, focus: TODAY_ROWS.length - 1 }), prop: (dc, G) => DS.home(dc, G, { focus: HOME_ROWS.length - 1 }),
    todayKeys: { START: "Run focused row", "UP / DOWN": "Rows, wrapping", BACK: "Leave the app" }, intents: homeIntents,
    notes: { all: ["Three rows only (focused ± 1); neighbour rows capped at 193·s."] } });
  add("home", { id: "home-sent", name: "Home, after a command", src: "ui/HomeHero.mc", kind: "adapted",
    today: dc => NH.hero(dc, { rows: TODAY_ROWS, msg: { text: "Sent", kind: "sent" } }), prop: (dc, G) => DS.home(dc, G, { msg: { text: "Sent", kind: "sent" } }),
    todayKeys: { START: "Run focused row" }, intents: homeIntents, notes: { all: ["Feedback stays in the hero's status line on every watch."] } });
  add("home", { id: "home-confirm", name: "Confirmation (native)", src: "api/ConfirmationPolicy.mc", kind: "scaled", tags: ["sys"],
    today: dc => Native.confirmation(dc, "Stop charging?"), prop: (dc, G) => DevNative.confirmation(dc, G, "Stop charging?"),
    todayKeys: { START: "Yes, send", DOWN: "No", BACK: "No" }, intents: P => ({ select: "Yes, send", tap: "Yes or No, by the half tapped", back: "No", extra: P.five ? [["DOWN", "No"]] : [] }),
    notes: { all: ["Native WatchUi.Confirmation stays (decided). Garmin draws it; positions on the AMOLED watches are approximate."],
      B: ["On touch a confirmation is one tap on Yes. Accepted: same as the touch fēnix today."], C: ["Same as Venu 3."] } });

  // status
  const statusIntents = page => P => ({ select: "Actions: Refresh" + (page === "charging" ? ", Charging details" : ""), tap: "Nothing (a tap never spends quota)", next: "Next page (wraps)", prev: "Previous page", back: "Home", menu: "Actions (same list)" });
  const stNotes = { today: ["Positions are constants for 260 (TITLE_Y 34, HERO_VALUE_Y 64, LINES_Y 142, AGE_Y 192, STATUS_Y 212)."],
    all: ["Stacked from the title down and the status line up, with measured font heights: reproduces 34/64/142/192/212 on the fēnix.",
      "MENU (hold UP / hold BACK / swipe left) opens the same Actions list as START (new: one rule for the menu route)."],
    B: ["Swipes page; START opens Actions; a tap is still consumed."], C: ["Indicator on: onActionMenu only fires when setActionMenuIndicator is enabled (M5)."],
    X1: ["Page dots: same arc formula at 9 o'clock, which on the rectangle reads as a near-vertical column (M11)."] };
  for (const page of ["lock", "fuel", "charging", "odo", "ac"]) {
    add("status", { id: "st-" + page, name: (NS.pages.indexOf(page) + 1) + " · " + TITLES[page], src: "ui/StatusPages.mc", kind: "adapted", fenix: "changed", indicator: true,
      today: DS.statusToday({ page }), prop: (dc, G) => DS.status(dc, G, { page }),
      todayKeys: { "UP / DOWN": "Previous / next page, wrapping", START: "Actions", BACK: "Home", Tap: "Nothing" }, intents: statusIntents(page),
      notes: page === "lock" ? Object.assign({}, stNotes, {
        all: stNotes.all.concat(["Lock grid (M12): three chip rows where they fit; otherwise the spacing squeezes (word to grid 9 → 4, row gap 2 → 1, age clearance 3 → 1) before two rows and \"+N\". Per watch: \"Lock grid\" in the watch table."]),
        C: stNotes.C.concat(["The indicator's keep-out limits only the right edge: the grid shifts left, so \"Windows\" fits next to it.",
          "At font size 1.4×: two rows and \"+N\" on the X1, one row on the round watches, with the hero word in small (M14). Open items sort first, so nothing insecure hides behind \"+N\"."]) })
        : page === "charging" || page === "fuel" ? Object.assign({}, stNotes, { all: stNotes.all.concat(["Hero number in the watch's hero font: FONT_NUMBER_MEDIUM where the Charging worst case fits, else FONT_NUMBER_MILD (M1)."]) }) : stNotes });
  }
  add("status", { id: "st-nodata", name: "Section without data", src: "ui/StatusPages.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: DS.statusToday({ page: "ac", nodata: true }), prop: (dc, G) => DS.status(dc, G, { page: "ac", nodata: true }),
    todayKeys: { START: "Actions (Refresh)" }, intents: statusIntents("ac"),
    notes: { today: ["\"START to refresh\" names a button (SG §8)."], all: ["Copy without a button name: \"Refresh from the menu\", the wording Charging already uses (M7)."] } });
  add("status", { id: "st-actions", name: "Status Actions menu", src: "ui/StatusPager.mc", kind: "scaled",
    today: menu("Actions", ACTIONS("charging")), prop: menu("Actions", ACTIONS("charging")),
    todayKeys: { "UP / DOWN": "Move", START: "Run", BACK: "Close" }, intents: () => LIST("Run the row"),
    notes: { today: ["Opened from the charging page: Refresh plus Charging details (the poc shows Refresh only)."], all: ["NightMenu: only the row tokens change (row = h/4, pill = FONT_MEDIUM + 14, width 212·s)."] } });

  // charging
  add("charging", { id: "ch-detail", name: "Charging detail", src: "ui/ChargingDetailView.mc", kind: "adapted", indicator: true,
    today: dc => NC.detail(dc, {}), todayGlyphMap: { "start:refresh": { glyph: "menu" }, "up:menu": null }, prop: (dc, G) => DS.charging(dc, G, {}),
    todayKeys: { START: "Charging list", MENU: "Charging list", Tap: "Charging list", BACK: "Back" },
    intents: () => ({ select: "Charging list", tap: "Charging list", menu: "Charging list", back: "Back" }),
    notes: { today: ["As built: START, MENU and a tap all open the list; one menu glyph at START (the poc still shows refresh at START and menu at UP)."],
      all: ["Stacked: hero at title − 5, chip, rows, age from the bottom; reproduces 58/134/160/202 on the fēnix."],
      C: ["Indicator on for consistency (M5); START and a tap already open the list."] } });
  add("charging", { id: "ch-active", name: "Charging detail, while charging", src: "ui/ChargingDetailView.mc", kind: "adapted", indicator: true, tags: ["ex"],
    today: dc => NC.detail(dc, { example: true }), todayGlyphMap: { "start:refresh": { glyph: "menu" }, "up:menu": null }, prop: (dc, G) => DS.charging(dc, G, { example: true }),
    todayKeys: { START: "Charging list" }, intents: () => ({ select: "Charging list", tap: "Charging list", menu: "Charging list", back: "Back" }), notes: {} });
  add("charging", { id: "ch-menu", name: "Charging list", src: "ui/ChargingDetailView.mc", kind: "scaled",
    today: menu("Charging", CH_MENU), prop: menu("Charging", CH_MENU), todayKeys: { "UP / DOWN": "Move", START: "Open", BACK: "Back" }, intents: () => LIST("Open"),
    notes: { today: ["As built: four rows incl. Set charge mode when the car lists modes."] } });
  add("charging", { id: "ch-limit", name: "Charge limit", src: "ui/ChargingLimitMenu.mc", kind: "scaled",
    today: dc => NC.limitMenu(dc, { value: 80, care: 80 }), prop: dc => NC.limitMenu(dc, { value: 80, care: 80 }),
    todayKeys: { "UP / DOWN": "Move", START: "Set", BACK: "Back" }, intents: () => LIST("Set the limit (confirmation)", "Back"),
    notes: { all: ["Already a list: the precedent for the target temperature (M6). ui-improvements C4 (stepper) is superseded."] } });
  add("charging", { id: "ch-mode", name: "Charge mode", src: "ui/ChargingModeView.mc", kind: "scaled", tags: ["ex"],
    today: dc => NC.mode(dc), prop: dc => NC.mode(dc), todayKeys: { "UP / DOWN": "Move", START: "Set mode", BACK: "Back" }, intents: () => LIST("Set mode (confirmation)", "Back"), notes: {} });
  add("charging", { id: "ch-profiles", name: "Charging profiles, not supported", src: "ui/ChargingProfilesView.mc", kind: "adapted",
    today: dc => NC.profilesUnsupported(dc), prop: (dc, G) => DS.profilesUnsupported(dc, G),
    todayKeys: { BACK: "Back" }, intents: () => ({ back: "Back", tap: "Nothing" }), notes: {} });
  add("charging", { id: "ch-profile-ex", name: "Charging profile page", src: "ui/ChargingProfilesView.mc", kind: "adapted", fenix: "changed", tags: ["ex"],
    today: dc => NC.profile(dc, { idx: 0, count: 2, indicator: "dots" }), prop: (dc, G) => DS.profile(dc, G),
    todayKeys: { "UP / DOWN": "Previous / next profile", START: "Retry (on error)", Tap: "= START: retries, spends quota", BACK: "Back" },
    intents: () => ({ select: "Retry (on error)", tap: "Nothing (consumed)", next: "Next profile", prev: "Previous profile", back: "Back" }),
    notes: { today: [{ flag: "Bug today: a tap arrives as onSelect, which retries and spends quota (no onTap in ChargingProfilesDelegate)." }],
      all: ["Tap consumed, like Status (fix for the bug).", "Stacked from the title; timers drop when they would pass h − 44·s."] } });

  // find my car
  const fcIntents = state => P => {
    const map = state === "parked" && P.map;
    return { select: map ? "Map" : "Find my car list", tap: map ? "Map" : "Find my car list", menu: "Find my car list: Navigate, Refresh", back: "Back" };
  };
  const fcNotes = { all: ["Address, distance and age stack from the top. Address widths on round watches: the chord of the track's text radius R − 6 with margin 12 ([158, 186] at y 46 on the fēnix, FindCarLayout.chordWidth); on the X1 the usable width.",
      "The age sits under the distance by the watch's hero font height, also when a long distance steps down to NUMBER_MILD."],
    noMap: ["No MapView: START (and a tap) open the list directly; START glyph = menu with the accent arc (M4)."], C: ["Indicator on (M5)."],
    X1: ["MapView exists: START = map, the list via swipe left / indicator. Track and pointer follow the rectangle."] };
  add("findcar", { id: "fc-parked", name: "Parked", src: "ui/LocationView.mc", kind: "adapted", fenix: "changed", indicator: true, tags: ["ex"],
    today: dc => NF.parked(dc), prop: (dc, G) => DS.fcParked(dc, G),
    todayKeys: { START: "Map", MENU: "List: Navigate, Refresh", Tap: "Map", BACK: "Back" }, intents: fcIntents("parked"),
    notes: Object.assign({}, fcNotes, { A: ["New: a menu glyph at UP marks the MENU list (it had none)."] }) });
  add("findcar", { id: "fc-gps", name: "Waiting for GPS", src: "ui/LocationView.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: dc => NF.gps(dc), prop: (dc, G) => DS.fcGps(dc, G), todayKeys: { START: "Map", MENU: "List" }, intents: fcIntents("parked"),
    notes: Object.assign({}, fcNotes, { all: ["\"Waiting for GPS\" in small at cy − small/2 − 2 (112 on the fēnix, as built), stepping down to tiny / xtiny where it does not fit the track."].concat(fcNotes.all.slice(0, 1)) }) });
  add("findcar", { id: "fc-moving", name: "Car is moving", src: "ui/LocationView.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: dc => NF.moving(dc), prop: (dc, G) => DS.fcMoving(dc, G), todayKeys: { MENU: "List: Refresh" }, intents: fcIntents("moving"),
    notes: { today: ["Refresh only via MENU."], all: ["START opens the list too, so Refresh no longer depends on MENU."] } });
  add("findcar", { id: "fc-nodata", name: "No data yet", src: "ui/LocationView.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: (dc, G) => DS.fcMessage(dc, G, ["No data yet"], "MENU to refresh", { glyph: false }), prop: (dc, G) => DS.fcMessage(dc, G, ["No data yet"], "Refresh from the menu"),
    todayKeys: { MENU: "List: Refresh", START: "Map (nothing to show)" }, intents: fcIntents("nodata"),
    notes: { today: [{ flag: "\"MENU to refresh\": the only route to Refresh, and there is no MENU key on " + DEV.list(DEV.namesWhere(d => d.profile === "C")) + "." }],
      all: ["START opens the list; copy without a button name (M7)."] } });
  add("findcar", { id: "fc-unavail", name: "Temporarily unavailable", src: "ui/LocationView.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: (dc, G) => DS.fcMessage(dc, G, ["Temporarily unavailable"], "MENU to try again", { glyph: false }), prop: (dc, G) => DS.fcMessage(dc, G, ["Temporarily unavailable"], "Try again from the menu"),
    todayKeys: { MENU: "List: Refresh" }, intents: fcIntents("nodata"), notes: { today: [{ flag: "\"MENU to try again\" names MENU." }] } });
  add("findcar", { id: "fc-menu", name: "Find my car list", src: "ui/LocationView.mc", kind: "scaled",
    today: menu("Find my car", FC_MENU), prop: menu("Find my car", FC_MENU), todayKeys: { "UP / DOWN": "Move", START: "Run", BACK: "Close" }, intents: () => LIST("Run the row"),
    notes: { today: ["As built: a NightMenu titled \"Find my car\" (the poc shows \"Actions\")."], B: ["Check saveWaypoint on the Venu 3S itself; hide Navigate if it fails (M13)."] } });
  add("findcar", { id: "fc-nav", name: "Navigate confirmation (native)", src: "ui/LocationView.mc", kind: "scaled", tags: ["sys"],
    today: dc => NF.nav(dc), prop: (dc, G) => DevNative.confirmation(dc, G, NF.NAV_TEXT), todayKeys: { START: "Yes", DOWN: "No" },
    intents: P => ({ select: "Yes: waypoint, exit to navigation", tap: "Yes or No", back: "No", extra: P.five ? [["DOWN", "No"]] : [] }), notes: {} });
  add("findcar", { id: "fc-map", name: "Map preview", src: "ui/MapPreviewView.mc", kind: "scaled", avail: hasMap, indicator: true, bg: "#FFFFAA",
    today: dc => NF.map(dc), prop: dc => NF.map(dc), todayKeys: { START: "Pan and zoom", MENU: "Navigate to car", BACK: "Back" },
    intents: () => ({ select: "Pan and zoom", tap: "Pan and zoom", menu: "Navigate to car", back: "Back (pan and zoom first)" }),
    notes: { today: ["Garmin's MapView; the app draws nothing on it."], all: ["MapView is missing on " + DEV.list(DEV.namesWhere(d => !d.mapView)) + ": there the file is excluded per product (jungle) and LocationView's has-check falls back. Per watch: \"MapView\" in the watch table."],
      X1: ["Swipe left opens the list in preview; in pan and zoom, touch pans (left swipe there belongs to the map)."] } });
  add("findcar", { id: "fc-map-menu", name: "Map list", src: "ui/MapPreviewView.mc", kind: "scaled", avail: hasMap,
    today: menu("Map", [{ label: "Navigate to car", icon: "pin" }]), prop: menu("Map", [{ label: "Navigate to car", icon: "pin" }]),
    todayKeys: { START: "Navigate (confirmation)", BACK: "Map" }, intents: () => LIST("Navigate (confirmation)", "Map"), notes: {} });

  // settings
  add("settings", { id: "set-menu", name: "Settings", src: "ui/screens/SettingsScreen.mc", kind: "adapted", newOnly: true,
    today: null, prop: menu("Settings", [{ label: "Tile order" }, { label: "Clear stored data" }]), intents: () => LIST("Open", "Back to home"),
    notes: { all: ["Home's Settings row opens this list (new in 1.3.0): Tile order, and Clear stored data, which up to 1.2 was only in the onboarding menu (US-007).",
      "Clear stored data asks first, as in onboarding; Yes erases the key, VIN, S-PIN and everything stored about the car, then closes the app, and the next start opens onboarding."] } });
  add("settings", { id: "set-temp", name: "Target temperature", src: "ui/TemperatureMenu.mc", kind: "adapted", fenix: "changed",
    today: dc => NSet.temp(dc), prop: dc => DS.tempList(dc),
    todayKeys: { UP: "+1, saved at once", DOWN: "−1", "Swipe up / down": "+1 / −1", Tap: "Nothing", BACK: "Done" }, intents: () => LIST("Set, back to settings", "Back"),
    notes: { today: [{ flag: "Stepper on UP/DOWN with + and − glyphs at buttons the two-button watches do not have." }],
      all: ["A list on every watch, the same move as the charge limit (decided, M6): 16 to 30 °C, current value focused and checked.",
        "List title shortened to \"Temperature\": \"Target temperature\" does not fit the NightMenu title area on any round watch (the stepper could move its title down; a menu title cannot)."] } });
  add("settings", { id: "set-temp-top", name: "Target temperature, top of the list", src: "ui/TemperatureMenu.mc", kind: "adapted", fenix: "changed", newOnly: true,
    today: null, prop: dc => DS.tempListTop(dc), intents: () => LIST("Set, back to settings", "Back"), notes: { all: ["Title in the NightMenu title area, visible at the top of the list."] } });
  add("settings", { id: "set-order", name: "Tile order", src: "ui/TileOrderView.mc", kind: "scaled",
    today: dc => NSet.order(dc), prop: dc => NSet.order(dc), todayKeys: { "UP / DOWN": "Move", START: "Edit item", BACK: "Back" }, intents: () => LIST("Edit item"), notes: {} });
  add("settings", { id: "set-order-item", name: "Tile order item", src: "ui/TileOrderView.mc", kind: "scaled",
    today: dc => NSet.item(dc), prop: dc => NSet.item(dc), todayKeys: { START: "Apply, back to the list" }, intents: () => LIST("Apply"), notes: {} });

  // onboarding
  const obIntents = (select, tap) => () => ({ select, tap, menu: "Onboarding list: Get a key, Clear stored data", back: "Leave the app", next: "Next part (long text only)", prev: "Previous part" });
  const obNotes = { A: ["Menu glyph stays at UP (hold UP)."], B: ["Menu glyph moves to BACK (hold BACK), grey, no arc (M9)."],
    C: ["No MENU key: indicator on in every state; onActionMenu opens the list.", "At font size 1.4× the text runs over and is cut with \"…\" (paging is the open proposal M14)."],
    all: ["Text block centred, chord widths with 26·s next to glyph rows.", "Text that runs past the outline even in FONT_XTINY fills the most lines that fit and ends in \"…\", as built. Open proposal (M14): split it into parts with page dots, next / previous page moving between them. Per watch at the default size: \"Onboarding text cut\" in the watch table."] };
  add("onboarding", { id: "ob-guide", name: "No key yet", src: "ui/OnboardingView.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: dc => NO.text(dc, NO.TEXT.guide, { menu: true, glyphs: true }), prop: (dc, G) => DS.obText(dc, G, NO.TEXT.guide, { menu: true, ok: true, glyphs: true }),
    todayKeys: { START: "Open the key page on the phone", MENU: "Onboarding list" }, intents: obIntents("Open the key page on the phone", "= START"),
    notes: Object.assign({}, obNotes, { all: obNotes.all.concat(["Proposal: a check glyph at START, since touch watches have no labelled START."]) }) });
  add("onboarding", { id: "ob-check", name: "Checking the key", src: "ui/OnboardingView.mc", kind: "scaled", indicator: true,
    today: dc => NO.text(dc, NO.TEXT.check), prop: (dc, G) => DS.obText(dc, G, NO.TEXT.check),
    todayKeys: { START: "Retry (after an error)", MENU: "Onboarding list" }, intents: obIntents("Retry (after an error)", "Nothing (a retry spends quota)"),
    notes: { today: [{ flag: "A tap retries too, which spends quota." }], all: ["Tap consumed on retry and on Blocked (new)."], C: ["Indicator on here too, so the list is always reachable."] } });
  add("onboarding", { id: "ob-expiry", name: "Key near expiry", src: "ui/OnboardingView.mc", kind: "scaled", indicator: true,
    today: dc => NO.text(dc, NO.TEXT.expiry, { ok: true, glyphs: true }), prop: (dc, G) => DS.obText(dc, G, NO.TEXT.expiry, { ok: true, glyphs: true }),
    todayKeys: { START: "Continue to home", MENU: "Onboarding list" }, intents: obIntents("Continue to home", "= START"), notes: {} });
  add("onboarding", { id: "ob-expired", name: "Key expired", src: "ui/OnboardingBlockedView.mc", kind: "adapted", fenix: "changed", indicator: true,
    today: dc => NO.text(dc, NO.TEXT.expired, { menu: true, glyphs: true }), prop: (dc, G) => DS.obText(dc, G, NO.TEXT.expired, { menu: true, glyphs: true }),
    todayKeys: { START: "Check again", MENU: "Onboarding list" }, intents: obIntents("Check again", "Nothing (consumed: spends quota)"), notes: obNotes });
  add("onboarding", { id: "ob-menu", name: "Onboarding list", src: "ui/OnboardingActionMenu.mc", kind: "scaled",
    today: dc => NO.menu(dc), prop: dc => NO.menu(dc), todayKeys: { START: "Open", BACK: "Close" }, intents: () => LIST("Open"), notes: { all: ["Clear stored data asks a native confirmation."] } });

  // Garmin UI
  add("garmin", { id: "gui-toast", name: "Toast (native)", src: "WatchUi.showToast", kind: "scaled", tags: ["sys"],
    today: dc => Native.toast(dc, NGUI.underLow, { text: "Command sent", icon: "check" }), prop: (dc, G, P) => DevNative.toast(dc, G, P.five ? NGUI.underLow : d => { blank(d); valueHero(d, G, 132, "100", "%"); }, { text: "Command sent", icon: "check" }),
    todayKeys: {}, intents: () => ({}), notes: { all: ["Garmin's own; on the AMOLED watches the layout is a stand-in (device files give a banner, not positions)."] } });
  add("garmin", { id: "gui-indicator", name: "Action menu indicator", src: "View.setActionMenuIndicator", kind: "adapted", newOnly: true, tags: ["sys"], indicator: true, avail: P => P.input === "C",
    today: null, prop: (dc, G) => { NGUI.under(dc); },
    intents: () => ({ menu: "The screen's action list" }),
    notes: { all: ["Watches without MENU only: Garmin's indicator at the right edge (position from actionMenuHint in the device file; drawn here as a stand-in).",
      "With it enabled a left swipe anywhere calls onActionMenu, so no screen may use left swipe for anything else."] } });

  return { list: S, DS };
})();
