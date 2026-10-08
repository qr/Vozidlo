// ================================================================ Style guide examples
// Draws the images used in docs/design/style-guide.md with the proof-of-concept drawing core
// (same primitives and fonts as the screens board). Each example renders into its own canvas;
// renderAll() returns {name: dataURL} so a headless browser can export them as PNG files.
(function () {
  const LABEL = "#8a8f96", DONT = "#d9534f", DO = "#2e9e6b";
  const card = (id, i) => { const c = CARDS.find(x => x.id === id); return c && c.neu[i || 0].draw; };

  function canvas(w, h) { const c = document.createElement("canvas"); c.width = w; c.height = h; return c; }
  // Draw a watch face (260 round) at x,y on ctx.
  function watch(ctx, x, y, draw, o = {}) {
    ctx.save(); ctx.translate(x, y);
    ctx.beginPath(); ctx.arc(130, 130, 130, 0, Math.PI * 2); ctx.clip();
    const dc = new Dc(ctx, 260, 260); dc.mono = !!o.mono; dc.setColor(T.TEXT_1, T.BG); dc.clear(); draw(dc);
    ctx.restore();
    ctx.save(); ctx.strokeStyle = "#3a3d42"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x + 130, y + 130, 131, 0, Math.PI * 2); ctx.stroke(); ctx.restore();
  }
  // Black rounded panel for components shown outside a watch face.
  function panel(ctx, x, y, w, h, draw) {
    ctx.save(); ctx.translate(x, y); ctx.fillStyle = "#000"; ctx.beginPath(); ctx.roundRect(0, 0, w, h, 14); ctx.fill();
    const dc = new Dc(ctx, w, h); draw(dc); ctx.restore();
  }
  function label(ctx, text, x, y, o = {}) {
    ctx.save(); ctx.font = `${o.weight || 600} ${o.size || 14}px "Barlow Semi Condensed", "Arial Narrow", sans-serif`;
    ctx.fillStyle = o.color || LABEL; ctx.textAlign = o.align || "center"; ctx.textBaseline = "alphabetic"; ctx.fillText(text, x, y); ctx.restore();
  }
  function pair(dontDraw, doDraw, dontText, doText) {
    const c = canvas(600, 330), x = c.getContext("2d");
    label(x, "Don't" + (dontText ? ": " + dontText : ""), 150, 22, { color: DONT, size: 16 });
    label(x, "Do" + (doText ? ": " + doText : ""), 450, 22, { color: DO, size: 16 });
    watch(x, 20, 50, dontDraw); watch(x, 320, 50, doDraw);
    return c;
  }

  const EX = {};

  EX.palette = () => {
    const toks = [["BG", T.BG, "canvas"], ["RULE", T.RULE, "lines, outlines"], ["TEXT_1", T.TEXT_1, "text, hero"], ["TEXT_2", T.TEXT_2, "units, ages, rows"],
      ["ACCENT", T.ACCENT, "focus, titles, dots"], ["EMERALD", T.EMERALD, "sub-label on accent"], ["WARNING", T.WARNING, "always with \"!\""], ["DESTRUCTIVE", T.DESTRUCTIVE, "always with \"!\""], ["POSITIVE", T.POSITIVE, "transient icons only"]];
    const c = canvas(9 * 100 + 20, 150), x = c.getContext("2d");
    toks.forEach(([n, col, role], i) => {
      const cx = 20 + i * 100;
      x.fillStyle = col; x.strokeStyle = "#3a3d42"; x.lineWidth = 2; x.beginPath(); x.roundRect(cx, 10, 80, 64, 10); x.fill(); x.stroke();
      label(x, n, cx + 40, 96, { size: 14, color: "#8a8f96" });
      label(x, col.replace("#", "0x"), cx + 40, 114, { size: 13, weight: 500 });
      label(x, role, cx + 40, 132, { size: 11, weight: 500 });
    });
    return c;
  };

  EX["type-roles"] = () => {
    const c = canvas(640, 290), x = c.getContext("2d");
    const rows = [["Title", "FONT_TINY, accent", 34], ["Hero digits + unit", "NUMBER_MEDIUM + MEDIUM", 72], ["Hero word", "FONT_MEDIUM", 148], ["Chip, age, status", "FONT_XTINY", 196], ["Empty-state line", "FONT_SMALL", 222]];
    watch(x, 10, 15, dc => {
      Ui.title(dc, "Fuel & range", 34);
      Ui.drawValueWithUnit(dc, 130, 58, "436", "km", {});
      Ui.drawHero(dc, { word: "Locked", icon: "locked", y: 134 });
      Ui.drawChip(dc, 130, 178, { icon: "locked", text: "Locked" });
      dc.setColor(T.TEXT_2); dc.drawText(130, 202, "xtiny", "12 min ago", J.CENTER);
    });
    const ys = [[50, rows[0]], [100, rows[1]], [150, rows[2]], [205, rows[3]]];
    ys.forEach(([y, r]) => { label(x, r[0], 300, y, { align: "left", size: 16, color: "#8a8f96" }); label(x, r[1], 300, y + 18, { align: "left", size: 13, weight: 500 }); });
    x.strokeStyle = "#5a5f66"; x.setLineDash([3, 3]); [[50, 60], [100, 100], [150, 165], [205, 205]].forEach(([y, wy]) => { x.beginPath(); x.moveTo(250, wy); x.lineTo(292, y - 5); x.stroke(); });
    return c;
  };

  EX["hero-value"] = () => {
    const c = canvas(600, 300), x = c.getContext("2d");
    label(x, "Number + unit", 150, 22, { size: 16 }); label(x, "Word + icon", 450, 22, { size: 16 });
    watch(x, 20, 35, dc => { Ui.title(dc, "Fuel & range"); Ui.drawValueWithUnit(dc, 130, 64, "436", "km", {}); dc.setColor(T.TEXT_1); dc.drawText(130, 142, "xtiny", "Petrol 62%", J.CENTER); dc.drawText(130, 162, "xtiny", "Electric 100%", J.CENTER); Ui.drawAge(dc, 192, 12); });
    watch(x, 320, 35, dc => { Ui.title(dc, "Air conditioning"); Ui.drawHero(dc, { word: "Off", icon: "fan", y: 70 }); dc.setColor(T.TEXT_1); dc.drawText(130, 128, "xtiny", "Windscreen heat off", J.CENTER); dc.drawText(130, 148, "xtiny", "Rear window heat off", J.CENTER); Ui.drawAge(dc, 192, 12); });
    return c;
  };

  EX.chips = () => {
    const c = canvas(640, 110), x = c.getContext("2d");
    const kinds = [["outline", { icon: "locked", text: "Locked" }], ["warn", { text: "Trunk open", kind: "warn" }], ["error", { text: "Offline", kind: "error" }], ["accent", { icon: "bolt", text: "Charging", kind: "accent" }], ["white", { icon: "check", text: "Battery care", kind: "white" }]];
    panel(x, 10, 10, 620, 56, dc => { let cx = 64; kinds.forEach(([k, ch]) => { Ui.drawChip(dc, cx, 18, ch); cx += 124; }); });
    kinds.forEach(([k], i) => label(x, ":" + k, 10 + 64 + i * 124, 92, { size: 14 }));
    return c;
  };

  EX.menu = () => {
    const c = canvas(300, 290), x = c.getContext("2d");
    watch(x, 20, 15, dc => Ui.menu(dc, { title: "Charging", items: [{ label: "Refresh", icon: "refresh" }, { label: "Charge limit", sub: "80%", icon: "battery" }, { label: "Charge mode", sub: "Manual", icon: "list" }, { label: "Profiles", icon: "list" }], focus: 1 }));
    return c;
  };

  EX["status-lines"] = () => {
    const c = canvas(760, 120), x = c.getContext("2d");
    const lines = [[":age", "12 min ago", T.TEXT_2, "xtiny"], [":sent", "Command sent", T.TEXT_1, "xtiny"], [":warn", "! 17 h ago", T.WARNING, "xtiny"], [":error", "! Phone not connected", T.DESTRUCTIVE, "xtiny"]];
    panel(x, 10, 10, 740, 60, dc => { lines.forEach(([k, t, col, f], i) => { dc.setColor(col); dc.drawText(85 + i * 185, 30, f, t, J.CENTER | J.VCENTER); }); });
    lines.forEach(([k], i) => label(x, k, 10 + 85 + i * 185, 96, { size: 14 }));
    return c;
  };

  EX.bezel = () => {
    const c = canvas(640, 300), x = c.getContext("2d");
    watch(x, 20, 20, dc => {
      Ui.drawRing(dc, 0.72, { fill: T.ACCENT, tick: 0.8 });
      Ui.drawPageIndicator(dc, 1, 5, "dots");
      Ui.drawHintArc(dc, "start", "accent"); NIcons.draw(dc, "menu", Math.round(130 + Math.cos(-30 * Math.PI / 180) * 108), Math.round(130 + Math.sin(-30 * Math.PI / 180) * 108), 6, T.TEXT_2);
      NIcons.draw(dc, "plus", Math.round(130 + Math.cos(150 * Math.PI / 180) * 108), Math.round(130 + Math.sin(150 * Math.PI / 180) * 108), 6, T.TEXT_2); Ui.drawHintArc(dc, "down", "dark");
      const a = 35 * Math.PI / 180, tip = [130 + Math.sin(a) * 117, 130 - Math.cos(a) * 117];
      const l = [130 + Math.sin(a - 0.12) * 129, 130 - Math.cos(a - 0.12) * 129], r = [130 + Math.sin(a + 0.12) * 129, 130 - Math.cos(a + 0.12) * 129];
      dc.setColor(T.TEXT_1); dc.fillPolygon([tip, l, r]);
      Ui.drawValueWithUnit(dc, 130, 92, "72", "%", {});
    });
    const notes = [["Ring r126, pen 4", "Bezel.ring(dc, frac, fill, tickFrac)"], ["Page dots r118", "Bezel.pageDots(dc, idx, count)"], ["Hint arc at a button", "Bezel.hintArc(dc, btn, kind)"], ["Glyph r108", "Bezel.glyph(dc, btn, icon, color, arc)"], ["Pointer r117..129", "Bezel.pointer(dc, angleRad, filled)"]];
    notes.forEach(([a, b], i) => { label(x, a, 320, 50 + i * 50, { align: "left", size: 16, color: "#8a8f96" }); label(x, b, 320, 68 + i * 50, { align: "left", size: 13, weight: 500 }); });
    return c;
  };

  EX.icons = () => {
    const names = ["locked", "unlocked", "open", "charging", "pluggedIn", "climate", "unknown", "battery", "range", "fan", "pin", "list", "gear", "stop", "refresh", "check", "cross", "bang", "plus", "minus", "menu", "map", "thermo"];
    const cols = 8, cw = 78, rows = Math.ceil(names.length / cols);
    const c = canvas(cols * cw + 20, rows * 80 + 20), x = c.getContext("2d");
    panel(x, 10, 10, cols * cw, rows * 80, dc => names.forEach((n, i) => { NIcons.draw(dc, n, 39 + (i % cols) * cw, 30 + Math.floor(i / cols) * 80, 11, T.TEXT_1); }));
    names.forEach((n, i) => label(x, n === "climate" ? "climateActive" : n, 10 + 39 + (i % cols) * cw, 10 + 66 + Math.floor(i / cols) * 80, { size: 12, color: "#b8bdc4", weight: 500 }));
    return c;
  };

  EX["app-icon"] = () => {
    const c = canvas(330, 215), x = c.getContext("2d");
    panel(x, 10, 10, 90, 170, dc => NG.appIcon(dc, 25, 65, 1));
    panel(x, 110, 10, 210, 170, dc => NG.appIcon(dc, 25, 5, 4));
    label(x, "40 px (actual)", 55, 202, { size: 14 }); label(x, "4x", 215, 202, { size: 14 });
    return c;
  };

  EX["dont-grey"] = () => pair(
    dc => { [["Start\nclimate", 35, 70], ["Stop\nclimate", 135, 70], ["Start\ncharging", 35, 122], ["Stop\ncharging", 135, 122]].forEach(([t, xx, yy]) => { dc.setColor(T.RULE); dc.fillRoundedRectangle(xx, yy, 90, 46, 8); dc.setColor(T.TEXT_1); dc.drawText(xx + 45, yy + 23, "xtiny", t, J.CENTER | J.VCENTER); }); },
    dc => { Ui.drawChipRow(dc, 96, [{ icon: "locked", text: "Locked" }, { icon: "pluggedIn", text: "Plugged in" }]); Ui.focusPill(dc, 24, 126, 212, 40, "Start climate"); dc.setColor(T.TEXT_2); dc.drawText(130, 186, "tiny", "Stop climate", J.CENTER | J.VCENTER); },
    "text on a grey fill", "outlines and the accent pill");

  EX["dont-number-font"] = () => {
    const prev = OPT.gaps; OPT.gaps = true;
    const c = pair(OLD_SCREENS["st-lock"].draw, dc => NS.page(dc, { page: "lock", indicator: "dots", start: "menu", idx: 0, count: 5, ageMin: 13 }), "a word in the digits-only font", "the word in FONT_MEDIUM");
    OPT.gaps = prev; return c;
  };

  EX["dont-clipped-hint"] = () => pair(OLD_SCREENS["st-fuel"].draw, dc => NS.page(dc, { page: "fuel", indicator: "dots", start: "menu", idx: 1, count: 5, ageMin: 12 }), "a text hint at the bottom edge", "a glyph and arc at the button");

  const screen = draw => { const c = canvas(280, 280), x = c.getContext("2d"); watch(x, 10, 10, draw); return c; };
  EX["screen-home"] = () => screen(card("home-mock", 1));
  EX["screen-status"] = () => screen(dc => NS.page(dc, { page: "lock", indicator: "dots", start: "menu", idx: 0, count: 5, ageMin: 13 }));
  EX["screen-charging"] = () => screen(card("ch-detail", 0));
  EX["screen-findcar"] = () => screen(card("fc-parked", 0));

  window.STYLE_EXAMPLES = EX;
  window.renderStyleExamples = function () {
    const out = {}, host = document.getElementById("style-out") || document.body;
    for (const [name, fn] of Object.entries(EX)) {
      try { const c = fn(); out[name] = c.toDataURL("image/png"); const fig = document.createElement("figure"); fig.appendChild(c); const cap = document.createElement("figcaption"); cap.textContent = name; fig.appendChild(cap); host.appendChild(fig); }
      catch (e) { out[name] = "ERROR " + e.message; }
    }
    const pre = document.createElement("pre"); pre.id = "style-data"; pre.textContent = JSON.stringify(out); pre.hidden = true; document.body.appendChild(pre);
    return out;
  };
})();
