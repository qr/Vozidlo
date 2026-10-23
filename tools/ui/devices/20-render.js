// ================================================================ DEVICES: renderer
// Draws a screen for one profile. Every watch is drawn in logical units: a frame 260 wide, scaled by
// s = w / 260 onto a canvas of the watch's real pixel size. Under that scale the poc's Night Panel code
// (centre 130, ring r 126, glyphs r 108) becomes "radii R - k·s, positions × s", which is the layout the
// app gets once Bezel/Theme take their size from the Dc. Fonts are the device's own, divided by s, so
// anything stacked from getFontHeight() stacks exactly as on the watch.
//
// withProfile() swaps the poc's shared state (FM, PX, FAMILY, row height, button angles, a few helpers)
// for the length of one synchronous draw and restores it afterwards. The swaps are listed in HOOKS so
// boot can check every hooked name still exists in the poc parts.
const DevRender = (function () {
  const MM = 5.5;   // CSS px per mm of display in "true size" mode
  let CUR = null; // {P, css, raw, opts}

  // ------------------------------------------------------------ Dc with per-device fonts
  // The poc Dc writes "700 <PX>px <FAMILY>" for the fēnix bitmap fonts; every other font gets its CSS face
  // from DEV.cssFace (TrueType: the point size in px; bitmap: calibrated so "0" is the device's advance).
  class DevDc extends Dc {
    _font(f) { return CUR && CUR.css && CUR.css[f] || `700 ${PX[f]}px ${FAMILY[f]}, sans-serif`; }
    charAdv(f, ch) {
      const a = FM[f].adv.get(ch); if (a !== undefined) return a;
      this.c.font = this._font(f); return this.c.measureText(ch).width || FM[f].h * 0.35;
    }
    drawText(x, y, f, text, just = J.LEFT) {
      const m = FM[f], c = this.c, lines = String(text).split("\n");
      let top = (just & J.VCENTER) ? y - Math.floor(lines.length * m.h / 2) : y;
      c.font = this._font(f); c.textBaseline = "alphabetic";
      for (const line of lines) {
        const w = this.getTextWidthInPixels(line, f);
        const hj = just & 3; let cx = hj === J.CENTER ? x - Math.floor(w / 2) : hj === J.LEFT ? x : x - w;
        if (Dc.onDraw) Dc.onDraw({ op: "text", font: f, text: line, top: top + this.ty, bottom: top + m.h + this.ty, asc: m.asc, left: cx + this.tx, right: cx + w + this.tx, color: this.rawFg, clip: this.clip, mono: this.mono });
        for (const ch of line) {
          const adv = this.charAdv(f, ch);
          c.fillStyle = this.fg; const gw = c.measureText(ch).width;
          c.fillText(ch, cx + (adv - gw) / 2, top + m.asc);
          cx += adv;
        }
        top += m.h;
      }
    }
  }

  // Bitmap fonts have no em size: like the poc's calibrate(), size the CSS face so "0" gets the device's advance.
  const CAL = {};
  let calCtx = null;
  function calibrated(face, adv0) {
    const key = face.weight + " " + face.family + " " + adv0;
    if (CAL[key] == null) {
      calCtx = calCtx || document.createElement("canvas").getContext("2d");
      calCtx.font = `${face.weight} 100px ${face.family}, sans-serif`;
      const w = calCtx.measureText("0").width;
      CAL[key] = w ? 100 * adv0 / w : adv0 * 1.8;
    }
    return CAL[key];
  }
  function cssFor(P, fm) {
    const css = {};
    if (!fm) return null;
    for (const k in fm) {
      const m = fm[k], size = m.em != null ? m.em : calibrated(m.face, m.adv.get("0") || m.h * 0.5);
      css[k] = `${m.face.weight} ${size}px ${m.face.family}, sans-serif`;
    }
    return css;
  }
  function scaleFm(fm, f) {
    const out = {};
    for (const k in fm) { const m = fm[k], n = Object.assign({}, m, { h: m.h * f, asc: m.asc * f, em: m.em == null ? null : m.em * f, a: m.a.map(a => a * f) }); n.adv = new Map(); [...n.w].forEach((ch, i) => n.adv.set(ch, n.a[i])); out[k] = n; }
    return out;
  }

  // ------------------------------------------------------------ geometry from the Dc
  // G: the layout tokens the adapted screens use, all in logical px in the 260 square (centre 130, 130).
  // On the X1 the frame runs from P.top (-11) to P.bottom (271); the square is centred in it.
  function geometry(P) {
    const round = P.shape === "round";
    const G = { P, round, top: P.top, bottom: P.bottom, cx: 130, cy: 130 };
    G.halfChord = dy => {
      if (round) return TB.halfChord(130, dy);
      const half = P.H / 2; if (dy >= half) return 0;
      const d = half - dy, rc = P.corner;
      return 130 - (d < rc ? rc - Math.sqrt(rc * rc - (rc - d) * (rc - d)) : 0);
    };
    // Keep-out of Garmin's action menu indicator (watches without MENU, indicator on): it sits at the right
    // edge, so it only limits the right side of a box from top to bottom; null where it does not apply.
    G.keepOutRight = (top, bottom, margin) => CUR && CUR.indicator && P.hint && bottom > P.hint.y && top < P.hint.y + P.hint.h ? Math.floor(P.hint.x) - margin : null;
    // Ui.usable, shape-aware: the width for centred text, so the keep-out narrows it on both sides.
    G.usable = (top, bottom, margin = 8) => {
      const dy = Math.max(Math.abs(top - 130), Math.abs(bottom - 130));
      let w = Math.max(0, 2 * Math.floor(G.halfChord(dy)) - 2 * TB.MARGIN - 2 * (margin - 8));
      const ko = G.keepOutRight(top, bottom, margin);
      if (ko != null) w = Math.min(w, Math.max(0, 2 * (ko - 130)));
      return w;
    };
    // [left, right] of the usable band from top to bottom: symmetric outline, keep-out on the right only,
    // for content that may shift left (the lock grid).
    G.span = (top, bottom, margin = 8) => {
      const dy = Math.max(Math.abs(top - 130), Math.abs(bottom - 130));
      const half = Math.max(0, Math.floor(G.halfChord(dy)) - TB.MARGIN - (margin - 8));
      const ko = G.keepOutRight(top, bottom, margin);
      return [130 - half, ko == null ? 130 + half : Math.max(130 - half, Math.min(130 + half, ko))];
    };
    // Find my car text inside the track: round = chord of the text radius R − 6 with margin 12
    // (FindCarLayout.chordWidth: [158, 186] for the address at y 46 on the fēnix); rectangle = usable.
    G.trackWidth = (top, bottom, margin = 12) => {
      if (!round) return G.usable(top, bottom, 16);
      let w = Math.max(0, TB.lineWidth(124, 130, top, bottom) - 2 * (margin - TB.MARGIN));
      const ko = G.keepOutRight(top, bottom, margin);
      if (ko != null) w = Math.min(w, Math.max(0, 2 * (ko - 130)));
      return w;
    };
    G.Tt = round ? 34 : P.top + 20;                                   // title top: SG §5 y 34, generalised
    G.statusTop = () => (round ? 260 - 29 : P.bottom - 20) - FM.xtiny.h;
    G.chipH = () => Math.max(FM.xtiny.h + 2, 20);                     // Chips.height()
    G.minDigitTop = round ? 12 : P.top + 12;                          // HomeHero.MIN_DIGIT_TOP
    // Charging worst case decides the hero number font for the whole watch (M1).
    G.heroFont = (() => {
      for (const f of ["numMed", "numMild"]) {
        const heroTop = G.Tt + FM.tiny.h - 5, chipTop = heroTop + FM[f].h + 2, row1 = chipTop + G.chipH() + 5;
        const rowsBottom = row1 + 2 * (FM.xtiny.h + 1) - 1, ageTop = (round ? 260 - 39 : P.bottom - 30) - FM.xtiny.h;
        if (rowsBottom + 2 <= ageTop) return f;
      }
      return "numMild";
    })();
    G.unitFont = G.heroFont === "numMed" ? "medium" : "small";
    // Button anchors: round = polar(r 108, button angle); rectangle = right edge at the key's y.
    G.anchor = (pos, r = 108) => {
      if (round) { const a = P.btn[pos] * Math.PI / 180; return [Math.round(130 + Math.cos(a) * r), Math.round(130 + Math.sin(a) * r)]; }
      return [260 - 22, P.keyY[pos]];
    };
    // Frame of the rectangle as a polyline (inset 4), clockwise from top centre, for ring, track and pointer.
    if (!round) {
      const inset = 4, x0 = inset, y0 = P.top + inset, x1 = 260 - inset, y1 = P.bottom - inset, r = P.corner - inset, pts = [];
      const seg = (ax, ay, bx, by) => { const n = Math.max(2, Math.round(Math.hypot(bx - ax, by - ay) / 2)); for (let i = 0; i < n; i++) pts.push([ax + (bx - ax) * i / n, ay + (by - ay) * i / n]); };
      const arc = (cx, cy, a0) => { for (let i = 0; i < 24; i++) { const a = (a0 + 90 * i / 24) * Math.PI / 180; pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
      seg(130, y0, x1 - r, y0); arc(x1 - r, y0 + r, -90); seg(x1, y0 + r, x1, y1 - r); arc(x1 - r, y1 - r, 0);
      seg(x1 - r, y1, x0 + r, y1); arc(x0 + r, y1 - r, 90); seg(x0, y1 - r, x0, y0 + r); arc(x0 + r, y0 + r, 180); seg(x0 + r, y0, 130, y0);
      G.frame = pts;
    }
    const strokePts = (dc, pts, pen, color) => {
      const c = dc.c; c.save(); c.strokeStyle = dc._m(color); c.lineWidth = pen; c.lineJoin = "round"; c.beginPath();
      pts.forEach(([x, y], i) => i ? c.lineTo(x, y) : c.moveTo(x, y)); c.stroke(); c.restore();
    };
    G.ring = (dc, frac, o = {}) => {
      if (round) return ORIG.drawRing(dc, frac, o);
      const pts = G.frame, n = pts.length;
      strokePts(dc, pts.concat([pts[0]]), o.pen || 4, o.track || T.RULE);
      if (frac > 0) strokePts(dc, pts.slice(0, Math.max(2, Math.round(n * Math.min(1, frac)))), o.pen || 4, o.fill || T.TEXT_1);
      if (o.tick != null) {
        const i = Math.round(n * o.tick) % n, [x, y] = pts[i], [xa, ya] = pts[(i + 1) % n], len = Math.hypot(xa - x, ya - y) || 1, nx = (ya - y) / len, ny = -(xa - x) / len;
        dc.setPenWidth(2); dc.setColor(o.tickColor || T.TEXT_1); dc.drawLine(x - nx * 3, y - ny * 3, x + nx * 7, y + ny * 7); dc.setPenWidth(1);
      }
    };
    G.track = dc => { if (round) return ORIG.nfRing(dc); strokePts(dc, G.frame.concat([G.frame[0]]), 3, T.RULE); };
    G.pointer = (dc, bearing, hasHeading) => {
      if (round) return ORIG.nfPointer(dc, bearing, hasHeading);
      const a = (bearing - 90) * Math.PI / 180;
      let best = G.frame[0], bd = 9;
      for (const p of G.frame) { const d = Math.abs(Math.atan2(Math.sin(Math.atan2(p[1] - 130, p[0] - 130) - a), Math.cos(Math.atan2(p[1] - 130, p[0] - 130) - a))); if (d < bd) { bd = d; best = p; } }
      const ux = Math.cos(a), uy = Math.sin(a), px = -uy, py = ux, tip = [best[0] + ux * 3, best[1] + uy * 3], bx = best[0] - ux * 15, by = best[1] - uy * 15;
      const l = [bx + px * 7, by + py * 7], r = [bx - px * 7, by - py * 7];
      dc.setColor(T.ACCENT);
      if (hasHeading) dc.fillPolygon([tip, l, r]);
      else { dc.setPenWidth(2); dc.drawLine(tip[0], tip[1], l[0], l[1]); dc.drawLine(l[0], l[1], r[0], r[1]); dc.drawLine(r[0], r[1], tip[0], tip[1]); dc.setPenWidth(1); }
    };
    // Hint at a button: 20° arc band on the ring (round), a short bar on the edge next to the key (rectangle).
    G.hintArc = (dc, pos, kind = "dark") => {
      if (!(pos in P.btn)) return;
      dc.setColor({ dark: T.TEXT_1, accent: T.ACCENT, positive: "#00AA00", destructive: T.DESTRUCTIVE }[kind] || T.TEXT_1);
      if (round) { dc.arcBand(130, 130, 124, 128, P.btn[pos] - 10, P.btn[pos] + 10); return; }
      dc.fillRoundedRectangle(255, Math.round(P.keyY[pos] - 22), 3, 44, 1.5);
    };
    G.glyph = (dc, pos, glyph, color = T.TEXT_2, arc = "dark") => {
      if (!(pos in P.btn)) return null;
      const [x, y] = G.anchor(pos); NIcons.draw(dc, glyph, x, y, 6, color); if (arc) G.hintArc(dc, pos, arc);
      return { x: x - 6, y: y - 6, w: 12, h: 12 };
    };
    // Garmin's action menu indicator (watches without MENU): stand-in at the device's actionMenuHint rect.
    G.indicator = dc => {
      if (!P.hint) return;
      const { x, y, w, h } = P.hint;
      dc.setColor(T.RULE); dc.fillRoundedRectangle(x, y, w, h, w / 2);
      const mx = x + w / 2, my = y + h / 2;
      dc.setColor(T.TEXT_1); dc.setPenWidth(2); dc.drawLine(mx + 2, my - 6, mx - 3, my); dc.drawLine(mx - 3, my, mx + 2, my + 6); dc.setPenWidth(1);
    };
    G.dots = (dc, idx, count) => Ui.drawPageIndicator(dc, idx, count, "dots");
    return G;
  }

  // ------------------------------------------------------------ swaps
  const ORIG = {};
  const HOOKS = ["FM", "PX", "FAMILY", "BTN", "Ui.ROW_H", "Ui.usable", "Ui.drawBezelGlyph", "Ui.drawHintArc", "Ui.drawRing", "Ui.drawChip",
    "Native.hintArc", "NH.ROW_H", "NH.HERO_BOTTOM", "NF.ring", "NF.pointer"];
  function captureOriginals() {
    Object.assign(ORIG, { drawBezelGlyph: Ui.drawBezelGlyph, drawHintArc: Ui.drawHintArc, drawRing: Ui.drawRing, drawChip: Ui.drawChip, usable: Ui.usable,
      nativeHint: Native.hintArc, nfRing: NF.ring, nfPointer: NF.pointer });
  }
  function missingHooks() {
    const has = { FM: typeof FM === "object", PX: typeof PX === "object", FAMILY: typeof FAMILY === "object", BTN: typeof BTN === "object",
      "Ui.ROW_H": typeof Ui.ROW_H === "number", "Ui.usable": typeof Ui.usable === "function", "Ui.drawBezelGlyph": typeof Ui.drawBezelGlyph === "function",
      "Ui.drawHintArc": typeof Ui.drawHintArc === "function", "Ui.drawRing": typeof Ui.drawRing === "function", "Ui.drawChip": typeof Ui.drawChip === "function",
      "Native.hintArc": typeof Native.hintArc === "function", "NH.ROW_H": typeof NH.ROW_H === "number", "NH.HERO_BOTTOM": typeof NH.HERO_BOTTOM === "number",
      "NF.ring": typeof NF.ring === "function", "NF.pointer": typeof NF.pointer === "function" };
    return HOOKS.filter(h => !has[h]);
  }

  // Glyph routing: where a glyph the poc draws at a button goes on this watch.
  //   o.glyphMap {"pos:glyph": null | {pos, glyph, color, arc}} applies first (as-built corrections, per-screen changes).
  //   Then the input profile: UP/DOWN/LIGHT do not exist on Venu; a MENU glyph moves to BACK (hold BACK) on B
  //   and becomes Garmin's action menu indicator on C; anything else at UP/DOWN is dropped (the screen itself
  //   then needs a touch route, which the board's reachability check verifies).
  function route(P, G, pos, glyph, color, arc, o) {
    const m = o.glyphMap && (o.glyphMap[pos + ":" + glyph] !== undefined ? o.glyphMap[pos + ":" + glyph] : o.glyphMap[pos + ":*"]);
    if (m === null) return null;
    if (m) { pos = m.pos || pos; glyph = m.glyph || glyph; if (m.color) color = m.color; if (m.arc !== undefined) arc = m.arc; }
    if (pos in P.btn) return { pos, glyph, color, arc };
    if (glyph === "menu" && P.input === "B") return { pos: "back", glyph, color: T.TEXT_2, arc: false };
    if (glyph === "menu" && P.input === "C") return { indicator: true };
    return null;
  }

  function withProfile(P, fn, o = {}) {
    let G = null;
    const save = { FM: Object.assign({}, FM), PX: Object.assign({}, PX), FAMILY: Object.assign({}, FAMILY), BTN: Object.assign({}, BTN),
      rowH: Ui.ROW_H, nhRow: NH.ROW_H, nhHero: NH.HERO_BOTTOM };
    const fm = o.raw && P.fm ? scaleFm(P.fm, P.s) : P.fm;
    CUR = { P, css: cssFor(P, fm), indicator: !!o.indicator, opts: o };
    try {
      if (fm) for (const k in FM) { if (fm[k]) FM[k] = fm[k]; }
      G = CUR.G = geometry(P);   // after the font swap: G.heroFont measures this watch's fonts
      for (const k in BTN) delete BTN[k]; Object.assign(BTN, P.btn);
      Ui.ROW_H = NH.ROW_H = o.raw ? P.rowH * P.s : P.rowH; NH.HERO_BOTTOM = 130 - Math.floor(NH.ROW_H / 2);
      Ui.usable = G.usable;
      Ui.drawRing = G.ring; NF.ring = G.track; NF.pointer = G.pointer;
      if (!P.today) Ui.drawChip = (dc, cx, y, c) => ORIG.drawChip(dc, cx, y, c.h ? c : Object.assign({}, c, { h: G.chipH() }));   // Chips.height(); today keeps the poc as drawn
      Ui.drawBezelGlyph = (dc, pos, glyph, color = T.TEXT_2, arc = "dark") => {
        const r = route(P, G, pos, glyph, color, arc, o);
        if (!r) return null;
        if (r.indicator) { G.indicator(dc); return null; }
        return G.glyph(dc, r.pos, r.glyph, r.color, r.arc);
      };
      Ui.drawHintArc = (dc, pos, kind) => { const r = route(P, G, pos, "*", null, kind, o); if (r && !r.indicator) G.hintArc(dc, r.pos, kind); };
      Native.hintArc = (dc, pos, color = T.TEXT_1) => { if (pos in P.btn) { dc.setColor(color); if (G.round) dc.arcBand(130, 130, 124, 128, P.btn[pos] - 10, P.btn[pos] + 10); else dc.fillRoundedRectangle(255, Math.round(P.keyY[pos] - 22), 3, 44, 1.5); } };
      return fn(G);
    } finally {
      for (const k in save.FM) FM[k] = save.FM[k];
      for (const k in BTN) delete BTN[k]; Object.assign(BTN, save.BTN);
      Ui.ROW_H = save.rowH; NH.ROW_H = save.nhRow; NH.HERO_BOTTOM = save.nhHero;
      Ui.usable = ORIG.usable; Ui.drawRing = ORIG.drawRing; NF.ring = ORIG.nfRing; NF.pointer = ORIG.nfPointer; Ui.drawChip = ORIG.drawChip;
      Ui.drawBezelGlyph = ORIG.drawBezelGlyph; Ui.drawHintArc = ORIG.drawHintArc; Native.hintArc = ORIG.nativeHint;
      CUR = null;
    }
  }

  // ------------------------------------------------------------ bezels
  // fēnix: the poc's bezelSvg. Venu (round, two buttons): thinner AMOLED case, START and BACK on the right.
  // Venu X1: rounded-rectangle case, buttons on the right edge at the device file's key positions.
  function bezelRound2(d, P) {
    const ring = d * 0.1, size = d + ring * 2, c = size / 2, ro = d / 2 + ring * 0.9;
    const btn = deg => { const a = (deg - 90) * Math.PI / 180, x = c + (ro + d * 0.03) * Math.cos(a), y = c + (ro + d * 0.03) * Math.sin(a);
      return `<rect x="${x - d * .03}" y="${y - d * .07}" width="${d * .06}" height="${d * .14}" rx="${d * .02}" fill="#8b8f94" stroke="#55595e" transform="rotate(${deg + 90} ${x} ${y})"/>`; };
    const labels = [["START", P.btn.start + 90], [P.input === "B" ? "BACK · hold MENU" : "BACK", P.btn.back + 90]];
    return `<svg class="bezel" viewBox="0 0 ${size} ${size}" aria-hidden="true">${btn(P.btn.start + 90)}${btn(P.btn.back + 90)}
      <circle cx="${c}" cy="${c}" r="${ro}" fill="#5d6166"/><circle cx="${c}" cy="${c}" r="${d / 2 + ring * 0.55}" fill="#2a2c2f"/><circle cx="${c}" cy="${c}" r="${d / 2 + 1.5}" fill="#000"/>
      ${labels.map(([L, deg]) => { const a = (deg - 90) * Math.PI / 180, lx = c + (d / 2 + ring * 0.3) * Math.cos(a), ly = c + (d / 2 + ring * 0.3) * Math.sin(a);
        return `<text x="${lx}" y="${ly}" fill="#c9ccd0" font-family="Barlow Semi Condensed, Arial Narrow, sans-serif" font-weight="700" font-size="${Math.max(7, d * 0.028)}" text-anchor="middle" dominant-baseline="middle" letter-spacing=".05em" transform="rotate(${deg - 90} ${lx} ${ly})">${L}</text>`; }).join("")}</svg>`;
  }
  function bezelRect(wpx, hpx, P) {
    const pad = wpx * 0.075, W = wpx + pad * 2, H = hpx + pad * 2, rx = P.corner * P.s / P.w * wpx;
    const key = (yDev, L) => { const y = pad + yDev / P.h * hpx;
      return `<rect x="${W - pad * 0.35}" y="${y - hpx * .07}" width="${pad * 0.55}" height="${hpx * .14}" rx="${pad * .2}" fill="#8b8f94" stroke="#55595e"/>
        <text x="${W - pad * 0.62}" y="${y}" fill="#c9ccd0" font-family="Barlow Semi Condensed, Arial Narrow, sans-serif" font-weight="700" font-size="${Math.max(7, wpx * 0.026)}" text-anchor="middle" dominant-baseline="middle" transform="rotate(90 ${W - pad * 0.62} ${y})">${L}</text>`; };
    const dd = P.dd, ky = id => dd.keys.find(k => k.id === id).y;
    return { W, H, pad, svg: `<svg class="bezel" viewBox="0 0 ${W + pad * 0.3} ${H}" aria-hidden="true">
      <rect x="0" y="0" width="${W}" height="${H}" rx="${rx + pad}" fill="#5d6166"/><rect x="${pad * 0.45}" y="${pad * 0.45}" width="${W - pad * 0.9}" height="${H - pad * 0.9}" rx="${rx + pad * 0.55}" fill="#2a2c2f"/>
      <rect x="${pad - 1.5}" y="${pad - 1.5}" width="${wpx + 3}" height="${hpx + 3}" rx="${rx + 1.5}" fill="#000"/>${key(ky("enter"), "START")}${key(ky("esc"), "BACK")}</svg>` };
  }

  // ------------------------------------------------------------ one watch
  // o: {mono, bezel, size: "mm"|"px", scale, raw, bg, label, indicator, glyphMap}
  function renderDevice(P, draw, o = {}) {
    const cssW = (o.size === "px" ? P.w * 0.62 : P.mm * MM) * (o.scale || 1), cssH = cssW * P.h / P.w;
    const fig = document.createElement("div"); fig.className = "watch dev " + P.shape;
    const cv = document.createElement("canvas"); cv.width = P.w; cv.height = P.h;
    cv.setAttribute("role", "img"); cv.setAttribute("aria-label", (o.label || "Watch screen") + ", " + P.name + ", " + P.w + " by " + P.h);
    if (o.bezel !== false) {
      if (P.shape === "rect") {
        const b = bezelRect(cssW, cssH, P); fig.style.width = (b.W + b.pad * 0.3) + "px"; fig.style.aspectRatio = (b.W + b.pad * 0.3) + " / " + b.H; fig.innerHTML = b.svg;
        Object.assign(cv.style, { left: (b.pad / (b.W + b.pad * 0.3) * 100) + "%", top: (b.pad / b.H * 100) + "%", width: (cssW / (b.W + b.pad * 0.3) * 100) + "%", height: (cssH / b.H * 100) + "%" });
      } else {
        const fen = P.five, ring = cssW * (fen ? 0.14 : 0.1), size = cssW + ring * 2;
        fig.style.width = size + "px"; fig.innerHTML = fen ? bezelSvg(cssW) : bezelRound2(cssW, P);
        const p = (ring / size * 100) + "%", w = (cssW / size * 100) + "%"; cv.style.left = cv.style.top = p; cv.style.width = cv.style.height = w;
      }
    } else { fig.classList.add("flat"); fig.style.width = cssW + "px"; fig.style.aspectRatio = P.w + " / " + P.h; }
    if (P.shape === "rect") cv.style.borderRadius = (P.corner * P.s / P.w * 100) + "% / " + (P.corner * P.s / P.h * 100) + "%";
    const ctx = cv.getContext("2d");
    ctx.fillStyle = o.bg || "#000"; ctx.fillRect(0, 0, P.w, P.h);
    const raw = !!o.raw;
    if (!raw) ctx.setTransform(P.s, 0, 0, P.s, 0, P.offY * P.s);
    const dc = new DevDc(ctx, raw ? P.w : 260, raw ? P.h : 260); dc.mono = !!o.mono;
    try { withProfile(P, G => draw(dc, G, P), o); }
    catch (e) {
      window.__jsErrors = (window.__jsErrors || 0) + 1; if (document.body) document.body.dataset.jsErrors = window.__jsErrors; console.error(e);
      try { dc.clearClip(); } catch (e2) {}
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = "#300000"; ctx.fillRect(0, 0, P.w, P.h);
      ctx.fillStyle = "#fff"; ctx.font = `700 ${P.w / 14}px Roboto, sans-serif`; ctx.textAlign = "center";
      ctx.fillText("Draw error", P.w / 2, P.h / 2); ctx.font = `400 ${P.w / 26}px Roboto, sans-serif`; ctx.fillText(String(e && e.message || e).slice(0, 40), P.w / 2, P.h / 2 + P.w / 14);
    }
    fig.appendChild(cv); return fig;
  }

  // A draw on a scratch canvas, for its return value only: the layout outcomes the watch table shows per column.
  function probe(P, draw, o = {}) {
    const cv = document.createElement("canvas"); cv.width = 260; cv.height = 260;
    return withProfile(P, G => draw(new DevDc(cv.getContext("2d"), 260, 260), G, P), o);
  }

  // Self-test: a fēnix screen through DevDc + withProfile must give the same pixels as the poc's own Dc, and
  // the fēnix 7 Pro column's device fonts (DEV_DATA) must equal the poc's FM table.
  function fontsMatchPoc() {
    const fm = DEV.derive("fenix7pro").fm; let bad = 0;
    for (const k in FM) { const a = FM[k], b = fm[k]; if (!b || a.h !== b.h || a.asc !== b.asc || a.w !== b.w || a.a.join() !== b.a.join()) bad++; }
    return bad;
  }
  function selftest() {
    const bad = fontsMatchPoc() + DEV.validate().length;
    if (bad) return 1e6 + bad;
    const P = DEV.derive("today"), draw = dc => NH.hero(dc, {});
    const a = document.createElement("canvas"); a.width = a.height = 260; const da = new Dc(a.getContext("2d"), 260, 260); draw(da);
    const b = document.createElement("canvas"); b.width = b.height = 260; const ctx = b.getContext("2d");
    ctx.fillStyle = "#000"; ctx.fillRect(0, 0, 260, 260);
    withProfile(P, () => draw(new DevDc(ctx, 260, 260)));
    const pa = a.getContext("2d").getImageData(0, 0, 260, 260).data, pb = ctx.getImageData(0, 0, 260, 260).data;
    let diff = 0; for (let i = 0; i < pa.length; i++) if (pa[i] !== pb[i]) diff++;
    return diff;
  }

  return { DevDc, geometry, withProfile, probe, renderDevice, selftest, fontsMatchPoc, captureOriginals, missingHooks, HOOKS, MM };
})();
