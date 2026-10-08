// ================================================================ CORE (shared by OLD and NEW)
// Font metrics from the fēnix 7 Pro "ww" font set (SDK .cft files): xtiny=ROBOTO_13B, tiny=18B, small=20B,
// medium=24B, large=25B, numMild=BIONIC_COND_30, numMed=BIONIC_COND_36, numHot=BIONIC_BOLD_50.
const FM = {"xtiny":{"h":19,"asc":15,"w":" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~°—…Š·","a":[4,4,5,8,8,10,9,3,5,5,7,8,4,6,5,5,8,8,8,8,8,8,8,8,8,8,4,4,7,8,7,7,12,9,9,9,9,8,8,9,10,4,8,9,8,12,10,10,9,10,9,9,9,9,9,12,9,9,8,4,6,4,6,6,5,7,8,7,8,8,5,8,8,4,4,8,4,12,8,8,8,8,5,7,5,8,7,10,7,7,7,5,4,5,9,6,10,11,9,5]},"tiny":{"h":29,"asc":23,"w":" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~°—…Š·","a":[5,6,7,12,12,15,14,4,8,8,11,11,6,9,7,8,12,12,12,12,12,12,12,12,12,12,6,6,10,12,11,10,18,14,13,13,13,11,11,14,14,6,11,13,11,18,14,14,13,14,13,13,13,13,14,18,13,13,12,6,9,6,9,9,8,11,12,11,12,11,8,12,12,6,6,11,6,17,12,12,12,12,8,11,7,12,11,15,11,10,11,7,6,7,13,9,15,16,13,7]},"small":{"h":32,"asc":25,"w":" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~°—…Š·","a":[6,7,8,13,13,17,15,4,8,8,12,12,6,9,8,9,13,13,13,13,13,13,13,13,13,13,7,7,12,13,12,12,20,16,15,15,15,13,12,15,16,7,13,14,12,20,16,16,15,16,14,14,14,15,15,20,15,14,14,7,10,7,10,10,9,12,13,12,13,12,9,13,13,7,6,12,7,19,13,13,13,13,9,12,8,13,12,17,12,12,12,8,7,8,15,10,17,17,14,7]},"medium":{"h":37,"asc":30,"w":" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~°—…Š·","a":[7,8,10,16,15,20,18,5,10,10,14,15,8,11,9,10,15,15,15,15,15,15,15,15,15,15,8,8,14,15,14,14,23,18,17,17,17,15,15,18,19,8,15,17,15,23,19,18,17,18,17,17,17,17,18,23,17,17,16,8,12,8,12,12,10,14,15,14,15,15,10,15,15,8,8,15,8,23,15,15,15,15,10,14,9,15,14,19,14,14,14,9,8,9,17,12,20,20,17,9]},"numMed":{"h":74,"asc":54,"w":" #%+-./0123456789:°","a":[14,38,42,31,18,11,23,27,27,27,27,27,27,27,27,27,27,11,20]}};
Object.assign(FM, {"large":{"h":40,"asc":32,"w":" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~°—…Š·","a":[8,9,11,17,17,21,19,5,11,11,15,16,8,12,10,11,17,17,17,17,17,17,17,17,17,17,9,8,15,17,15,15,25,20,19,19,19,16,16,19,20,9,16,18,16,25,20,20,19,20,18,18,18,19,19,25,19,18,18,9,13,9,13,13,11,16,16,15,16,16,11,17,16,8,8,16,8,25,16,17,16,17,11,15,10,16,15,21,15,15,15,10,8,10,19,13,22,22,18,9]},"numMild":{"h":60,"asc":44,"w":" #%+-./0123456789:°","a":[11,32,34,26,15,9,19,23,23,23,23,23,23,23,23,23,23,9,16]},"numHot":{"h":100,"asc":73,"w":" #%+-./0123456789:°","a":[17,52,57,40,24,16,31,40,40,40,40,40,40,40,40,40,40,16,29]}});
const FAMILY = { xtiny: "Roboto", tiny: "Roboto", small: "Roboto", medium: "Roboto", large: "Roboto", numMild: "'Roboto Condensed'", numMed: "'Roboto Condensed'", numHot: "'Roboto Condensed'" };
for (const k in FM) { const m = FM[k]; m.adv = new Map(); [...m.w].forEach((ch, i) => m.adv.set(ch, m.a[i])); }

// Connect IQ Graphics.COLOR_* values
const COL = { WHITE: "#FFFFFF", LT_GRAY: "#AAAAAA", DK_GRAY: "#555555", BLACK: "#000000", RED: "#FF0000", DK_RED: "#AA0000",
  ORANGE: "#FF5500", YELLOW: "#FFAA00", GREEN: "#00FF00", DK_GREEN: "#00AA00", BLUE: "#00AAFF", DK_BLUE: "#0000FF" };

const OPT = { scale: 1, bezel: true, gaps: false, guides: false, mono: false };
try { const s = JSON.parse(localStorage.getItem("vozidlo-poc-opt") || "null"); if (s) Object.assign(OPT, s); } catch (e) {}

let PX = {};  // calibrated CSS font size per watch font
function calibrate() {
  const c = document.createElement("canvas").getContext("2d");
  for (const k in FM) {
    c.font = `700 100px ${FAMILY[k]}, sans-serif`;
    PX[k] = 100 * FM[k].adv.get("0") / c.measureText("0").width;
  }
}

// ---------------------------------------------------------------- a tiny Dc
// Port of the Connect IQ drawing calls the app uses, plus a few the NEW design needs
// (drawArc, arcBand, setClip). Angles are CANVAS degrees: 0 = 3 o'clock, clockwise.
const J = { CENTER: 1, LEFT: 2, RIGHT: 0, VCENTER: 4 };
class Dc {
  constructor(ctx, w, h) { this.c = ctx; this.w = w; this.h = h; this.fg = COL.WHITE; this.rawFg = COL.WHITE; this.bg = COL.BLACK; this.pen = 1; this.mono = false; this.clip = null; this.tx = 0; this.ty = 0; }
  getWidth() { return this.w; } getHeight() { return this.h; }
  _m(col) { return this.mono && col && col.toUpperCase() !== "#000000" ? "#FFFFFF" : col; }
  setColor(fg, bg) { this.rawFg = fg; this.fg = this._m(fg); if (bg && bg !== "T") this.bg = this._m(bg); }
  setPenWidth(p) { this.pen = p; }
  translate(x, y) { this.tx += x; this.ty += y; this.c.translate(x, y); }
  setClip(x, y, w, h) { this.c.save(); this.c.beginPath(); this.c.rect(x, y, w, h); this.c.clip(); this.clip = { x: x + this.tx, y: y + this.ty, w, h }; }
  clearClip() { if (this.clip) { this.c.restore(); this.clip = null; } }
  _fill(l, t, r, b) { if (Dc.onDraw) Dc.onDraw({ op: "fill", left: l + this.tx, top: t + this.ty, right: r + this.tx, bottom: b + this.ty, color: this.rawFg, clip: this.clip, mono: this.mono }); }
  clear() { this.c.fillStyle = this.bg; this.c.fillRect(0, 0, this.w, this.h); }
  fillRectangle(x, y, w, h) { this.c.fillStyle = this.fg; this.c.fillRect(x, y, w, h); this._fill(x, y, x + w, y + h); }
  fillRoundedRectangle(x, y, w, h, r) { const c = this.c; c.fillStyle = this.fg; c.beginPath(); c.roundRect(x, y, w, h, r); c.fill(); this._fill(x, y, x + w, y + h); }
  drawRoundedRectangle(x, y, w, h, r) { const c = this.c, p = this.pen; c.strokeStyle = this.fg; c.lineWidth = p; c.beginPath(); c.roundRect(x + p / 2, y + p / 2, w - p, h - p, r); c.stroke(); }
  drawRectangle(x, y, w, h) { const c = this.c, p = this.pen; c.strokeStyle = this.fg; c.lineWidth = p; c.strokeRect(x + p / 2, y + p / 2, w - p, h - p); }
  drawCircle(cx, cy, r) { const c = this.c; c.strokeStyle = this.fg; c.lineWidth = this.pen; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke(); }
  fillCircle(cx, cy, r) { const c = this.c; c.fillStyle = this.fg; c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.fill(); this._fill(cx - r, cy - r, cx + r, cy + r); }
  drawLine(x1, y1, x2, y2) { const c = this.c; c.strokeStyle = this.fg; c.lineWidth = this.pen; c.lineCap = "butt"; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke(); }
  fillPolygon(pts) { const c = this.c; c.fillStyle = this.fg; c.beginPath(); pts.forEach(([x, y], i) => i ? c.lineTo(x, y) : c.moveTo(x, y)); c.closePath(); c.fill();
    const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]); this._fill(Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)); }
  drawArc(cx, cy, r, a0, a1) { const c = this.c; c.strokeStyle = this.fg; c.lineWidth = this.pen; c.lineCap = "butt"; c.beginPath(); c.arc(cx, cy, r, a0 * Math.PI / 180, a1 * Math.PI / 180); c.stroke(); }
  arcBand(cx, cy, r0, r1, a0, a1) { const c = this.c, A0 = a0 * Math.PI / 180, A1 = a1 * Math.PI / 180; c.fillStyle = this.fg; c.beginPath(); c.arc(cx, cy, r1, A0, A1); c.arc(cx, cy, r0, A1, A0, true); c.closePath(); c.fill(); }
  getFontHeight(f) { return FM[f].h; }
  charAdv(f, ch) { const a = FM[f].adv.get(ch); if (a !== undefined) return a; const c = this.c; c.font = `700 ${PX[f]}px ${FAMILY[f]}, sans-serif`; return Math.round(c.measureText(ch).width) || Math.round(FM[f].h * 0.35); }
  getTextWidthInPixels(s, f) { let w = 0; for (const ch of String(s)) w += this.charAdv(f, ch); return w; }
  drawText(x, y, f, text, just = J.LEFT) {
    const m = FM[f], c = this.c, lines = String(text).split("\n");
    let top = (just & J.VCENTER) ? y - Math.floor(lines.length * m.h / 2) : y;
    c.font = `700 ${PX[f]}px ${FAMILY[f]}, sans-serif`; c.textBaseline = "alphabetic";
    for (const line of lines) {
      const w = this.getTextWidthInPixels(line, f);
      const hj = just & 3; let cx = hj === J.CENTER ? x - Math.floor(w / 2) : hj === J.LEFT ? x : x - w;
      if (Dc.onDraw) Dc.onDraw({ op: "text", font: f, text: line, top: top + this.ty, bottom: top + m.h + this.ty, asc: m.asc, left: cx + this.tx, right: cx + w + this.tx, color: this.rawFg, clip: this.clip, mono: this.mono });
      for (const ch of line) {
        const adv = this.charAdv(f, ch), known = m.adv.has(ch);
        if (!known && OPT.gaps) {
          c.save(); c.strokeStyle = "#FF00FF"; c.lineWidth = 1.5; c.setLineDash([3, 2]);
          c.strokeRect(cx + 1.5, top + m.asc * 0.35, adv - 3, m.asc * 0.65); c.restore();
        } else {
          c.fillStyle = this.fg; const gw = c.measureText(ch).width;
          c.fillText(ch, cx + (adv - gw) / 2, top + m.asc);
        }
        cx += adv;
      }
      top += m.h;
    }
  }
}
Dc.onDraw = null;   // fitcheck hook: receives {op:"text"|"fill", ...absolute coordinates}


// ---------------------------------------------------------------- ports of shared helpers
const R = 130;
const TB = {
  MARGIN: 8,
  halfChord(r, dy) { const r2 = r * r, d2 = dy * dy; return d2 >= r2 ? 0 : Math.floor(Math.sqrt(r2 - d2)); },
  lineWidth(r, cy, top, bottom) { const dy = Math.max(Math.abs(top - cy), Math.abs(bottom - cy)); const u = 2 * this.halfChord(r, dy) - 2 * this.MARGIN; return u > 0 ? u : 0; },
  wrap(text, widths, measure) {
    const lines = [], words = text.split(/\s+/).filter(Boolean); let cur = "";
    const wf = i => widths.length === 0 ? 0 : widths[Math.min(i, widths.length - 1)];
    for (const word of words) {
      let limit = wf(lines.length); const cand = cur ? cur + " " + word : word;
      if (measure(cand) <= limit) { cur = cand; continue; }
      if (cur) { lines.push(cur); cur = ""; limit = wf(lines.length); }
      if (measure(word) <= limit) { cur = word; continue; }
      let rest = word;
      while (measure(rest) > limit && rest.length > 1) { let n = 1; while (n < rest.length && measure(rest.slice(0, n + 1)) <= limit) n++; lines.push(rest.slice(0, n)); rest = rest.slice(n); limit = wf(lines.length); }
      cur = rest;
    }
    if (cur) lines.push(cur); return lines;
  },
  // TextBlock.draw: wraps into the circle's chord widths, centred vertically
  draw(dc, text, f, color) {
    const lh = FM[f].h, cy = dc.getHeight() / 2, measure = s => dc.getTextWidthInPixels(s, f);
    let lines = [], count = 1;
    for (let pass = 0; pass < 6; pass++) {
      const top = cy - Math.floor(count * lh / 2), widths = [];
      for (let i = 0; i < count; i++) widths.push(this.lineWidth(R, cy, top + i * lh, top + i * lh + lh));
      lines = this.wrap(text, widths, measure);
      if (lines.length === count || lines.length === 0) break; count = lines.length;
    }
    const maxLines = Math.floor(dc.getHeight() / lh);
    if (lines.length > maxLines) { lines = lines.slice(0, maxLines); lines[lines.length - 1] += "…"; }
    dc.setColor(color); const top = cy - Math.floor(lines.length * lh / 2);
    lines.forEach((l, i) => dc.drawText(130, top + i * lh, f, l, J.CENTER));
  },
  // TextBlock.drawFittedLine: moves the line up until it fits the circle
  fitted(dc, text, f, color, preferredY) {
    const lh = FM[f].h, half = Math.floor(lh / 2), cy = 130; let y = preferredY, found = cy;
    const tw = dc.getTextWidthInPixels(text, f);
    while (y > cy) { if (this.lineWidth(R, cy, y - half, y + half) >= tw) { found = y; break; } y -= 2; }
    if (y <= cy) found = cy;
    dc.setColor(color); dc.drawText(130, found, f, text, J.CENTER); return found;
  }
};

const Icons = {
  sw(r) { const w = Math.trunc(r / 4); return w < 2 ? 2 : w; },
  draw(dc, s, cx, cy, r, color) {
    const t = Math.trunc; dc.setColor(color); dc.setPenWidth(this.sw(r));
    if (s === "locked" || s === "unlocked") {
      const bw = t(r * 1.5), bh = t(r * 1.05), bx = t(cx - bw / 2), by = t(cy - r * 0.1), sw = t(r * 0.9), sh = t(r * 1.05);
      const sx = s === "locked" ? t(cx - sw / 2) : t(bx - r * 0.05), sy = s === "locked" ? t(cy - r * 1.05) : t(cy - r * 1.35);
      dc.drawRoundedRectangle(sx, sy, sw, sh, t(sw / 2)); dc.fillRoundedRectangle(bx, by, bw, bh, t(r * 0.25));
    } else if (s === "open") {
      const px = t(cx - r * 0.5); dc.drawLine(px, t(cy - r), px, t(cy + r));
      dc.fillPolygon([[px, t(cy - r * 0.6)], [px, t(cy - r * 0.05)], [t(cx + r * 0.7), t(cy - r * 0.35)]]);
    } else if (s === "charging") {
      const k = r / 7; dc.fillPolygon([[1, -7], [-5, 1], [-0.5, 1], [-1.5, 7], [5, -1.5], [0.5, -1.5]].map(([a, b]) => [t(cx + a * k), t(cy + b * k)]));
    } else if (s === "pluggedIn") {
      dc.fillRoundedRectangle(t(cx - r * 0.5), t(cy - r * 0.1), t(r), t(r * 0.9), t(r * 0.2));
      dc.fillRoundedRectangle(t(cx - r * 0.32), t(cy - r * 0.7), t(r * 0.18), t(r * 0.6), t(r * 0.06));
      dc.fillRoundedRectangle(t(cx + r * 0.12), t(cy - r * 0.7), t(r * 0.18), t(r * 0.6), t(r * 0.06));
    } else if (s === "climate") {
      dc.drawLine(t(cx - r), cy, t(cx + r), cy); dc.drawLine(cx, t(cy - r), cx, t(cy + r));
      dc.drawLine(t(cx - r * .7), t(cy - r * .7), t(cx + r * .7), t(cy + r * .7)); dc.drawLine(t(cx - r * .7), t(cy + r * .7), t(cx + r * .7), t(cy - r * .7));
    } else { dc.drawCircle(cx, cy, r); dc.drawLine(t(cx - r * .5), cy, t(cx + r * .5), cy); }
    dc.setPenWidth(1);
  },
  forLock(raw) { return raw == null ? "unknown" : raw === "YES" ? "locked" : raw === "NO" ? "unlocked" : (raw === "OPENED" || raw === "TRUNK_OPENED") ? "open" : "unknown"; },
  forCharging(raw) { return raw === "CHARGING" ? "charging" : ["READY_FOR_CHARGING", "CONSERVING", "CHARGING_INTERRUPTED"].includes(raw) ? "pluggedIn" : null; },
  forClimate(raw) { return ["HEATING", "COOLING", "VENTILATION", "HEATING_AUXILIARY"].includes(raw) ? "climate" : null; }
};
const DASH = "—";

// ---------------------------------------------------------------- mock vehicle (mock/vehicle_data.py)
const MOCK = { soc: 100, chargingState: "READY_FOR_CHARGING", lock: "YES", climate: "OFF",
  address: "Testlaan 1, 1000 AA Teststad, Netherlands", odometer: 123456, range: 436 };
const lockLabel = r => r == null ? DASH : r === "YES" ? "LOCKED" : r === "NO" ? "UNLOCKED" : r === "OPENED" ? "OPEN" : r === "TRUNK_OPENED" ? "TRUNK OPEN" : r;

function bezelSvg(d) {
  // d = screen diameter in CSS px; ring and buttons scale with it
  const ring = d * 0.14, size = d + ring * 2, c = size / 2, ro = d / 2 + ring * 0.9;
  const btn = (deg) => {
    const a = (deg - 90) * Math.PI / 180, x = c + (ro + d * 0.035) * Math.cos(a), y = c + (ro + d * 0.035) * Math.sin(a);
    return `<rect x="${x - d * .035}" y="${y - d * .075}" width="${d * .07}" height="${d * .15}" rx="${d * .02}" fill="#8b8f94" stroke="#55595e" transform="rotate(${deg + 90} ${x} ${y})"/>`;
  };
  return `<svg class="bezel" viewBox="0 0 ${size} ${size}" aria-hidden="true">
    ${btn(300)}${btn(270)}${btn(240)}${btn(60)}${btn(120)}
    <circle cx="${c}" cy="${c}" r="${ro}" fill="#6e7378"/>
    <circle cx="${c}" cy="${c}" r="${ro - ring * .08}" fill="#4a4e53"/>
    <circle cx="${c}" cy="${c}" r="${d / 2 + ring * 0.62}" fill="#2a2c2f"/>
    <circle cx="${c}" cy="${c}" r="${d / 2 + 2}" fill="#000"/>
    ${[300, 270, 240, 60, 120].map((deg, i) => { const L = ["LIGHT", "UP · MENU", "DOWN", "START", "BACK"][i]; const a = (deg - 90) * Math.PI / 180, lx = c + (d / 2 + ring * 0.42) * Math.cos(a), ly = c + (d / 2 + ring * 0.42) * Math.sin(a);
      return `<text x="${lx}" y="${ly}" fill="#c9ccd0" font-family="Barlow Semi Condensed, Arial Narrow, sans-serif" font-weight="700" font-size="${Math.max(7, d * 0.03)}" text-anchor="middle" dominant-baseline="middle" letter-spacing=".05em" transform="rotate(${deg > 180 ? deg - 270 : deg - 90} ${lx} ${ly})">${L}</text>`; }).join("")}
  </svg>`;
}

function guides(dc) {
  const c = dc.c; c.save(); c.strokeStyle = "rgba(255,0,255,.65)"; c.lineWidth = 1; c.setLineDash([4, 3]);
  c.beginPath(); c.arc(130, 130, 122, 0, Math.PI * 2); c.stroke();
  c.beginPath(); c.moveTo(130, 0); c.lineTo(130, 260); c.moveTo(0, 130); c.lineTo(260, 130); c.stroke();
  c.strokeStyle = "rgba(0,170,255,.5)"; c.setLineDash([2, 4]);
  for (let y = 52; y < 260; y += 52) { c.beginPath(); c.moveTo(0, y); c.lineTo(260, y); c.stroke(); }
  c.restore();
}


// ================================================================ NEW DESIGN CORE ("Night Panel")
// Theme tokens, label/age helpers, icon set, drawing helpers and Garmin's native UI.
// Every NEW screen is built from these; agents do not draw colours or fonts by hand
// except through T.* and the font names in FM.
// ACCENT = Škoda Electric Green #78FAAE (read from skoda-auto.com, 2026-10-07) as the fēnix 7 Pro's
// 64-colour palette shows it; Emerald #0E3A2F becomes #005555 there (too dark for an accent on black).
const T = { BG: "#000000", RULE: "#555555", TEXT_1: "#FFFFFF", TEXT_2: "#AAAAAA", ACCENT: "#55FFAA", EMERALD: "#005555",
  POSITIVE: "#00FF00", WARNING: "#FFAA00", DESTRUCTIVE: "#FF0000", BLACK: "#000000" };
// Retired colours (orange meant both "error" and "unlocked" in the app today).
const BANNED = ["#FF5500"];
// Canvas angle (deg) of each physical button on the fēnix 7 Pro bezel.
const BTN = { start: -30, back: 30, down: 150, up: 180, light: 210 };

const Age = {
  // NEW age format (B4): "Just now", "5 min ago", "2 h ago", "3 d ago"
  short(min) { if (min < 1) return "Just now"; if (min < 60) return min + " min"; if (min < 1440) return Math.floor(min / 60) + " h"; return Math.floor(min / 1440) + " d"; },
  text(min) { const s = Age.short(min); return s === "Just now" ? s : s + " ago"; },
  stale(min) { return min > 60; }
};

const Labels = {
  human(raw) { if (raw == null) return "—"; const s = String(raw).toLowerCase().replace(/_/g, " "); return s.charAt(0).toUpperCase() + s.slice(1); },
  charging(raw) { return ({ CHARGING: "Charging", READY_FOR_CHARGING: "Plugged in", CONNECT_CABLE: "Plug in", CHARGING_INTERRUPTED: "Paused", CONSERVING: "Conserving", DISCHARGING: "Discharging" })[raw] || Labels.human(raw); },
  lock(raw) { return ({ YES: "Locked", NO: "Unlocked", OPENED: "Open", TRUNK_OPENED: "Trunk open", UNKNOWN: "Unknown" })[raw] || Labels.human(raw); },
  state(raw) { return ({ CLOSED: "Closed", OPEN: "Open", ON: "On", OFF: "Off" })[raw] || Labels.human(raw); },
  engine(raw) { return ({ GASOLINE: "Petrol", ELECTRIC: "Electric", DIESEL: "Diesel", CNG: "Gas" })[raw] || Labels.human(raw); },
  climate(raw) { return ({ OFF: "Off", HEATING: "Heating", COOLING: "Cooling", VENTILATION: "Ventilating", HEATING_AUXILIARY: "Aux heating" })[raw] || Labels.human(raw); },
  chargeType(raw) { return ({ AC: "AC", DC: "DC fast", OFF: "Not charging" })[raw] || Labels.human(raw); }
};

// NEW mock: same car as mock/vehicle_data.py, plus the fields the new screens show.
const NMOCK = { soc: 100, rangeKm: 36, limit: null, totalRange: 436, odometer: 123456,
  lock: "YES", doors: "CLOSED", windows: "CLOSED", bonnet: "CLOSED", trunk: "CLOSED", lights: "OFF", sunroof: "UNSUPPORTED",
  charging: "READY_FOR_CHARGING", climate: "OFF", targetTemp: 21, heatFront: "OFF", heatRear: "OFF",
  primary: { engine: "GASOLINE", pct: 62 }, secondary: { engine: "ELECTRIC", pct: 100 },
  address: "Testlaan 1, 1000 AA Teststad, Netherlands", ageMin: 12, statusAgeMin: 13 };

// ---------------------------------------------------------------- icons
// Solid silhouettes (B4). Old StateIcons names keep working; new names are added.
const NIcons = {
  draw(dc, name, cx, cy, r, color) {
    const t = Math.trunc;
    if (["locked", "unlocked", "open", "charging", "pluggedIn", "climate", "unknown"].includes(name)) { Icons.draw(dc, name, cx, cy, r, color); return; }
    dc.setColor(color); dc.setPenWidth(Math.max(2, t(r / 3)));
    switch (name) {
      case "bolt": Icons.draw(dc, "charging", cx, cy, r, color); break;
      case "battery": dc.drawRoundedRectangle(t(cx - r), t(cy - r * .55), t(r * 1.8), t(r * 1.1), 2); dc.fillRectangle(t(cx + r * .8), t(cy - r * .25), t(r * .25), t(r * .5)); dc.fillRectangle(t(cx - r * .7), t(cy - r * .3), t(r * 1.2), t(r * .6)); break;
      case "range": dc.fillPolygon([[t(cx - r), cy], [t(cx + r * .2), t(cy - r * .8)], [t(cx + r * .2), t(cy - r * .3)], [t(cx + r), t(cy - r * .3)], [t(cx + r), t(cy + r * .3)], [t(cx + r * .2), t(cy + r * .3)], [t(cx + r * .2), t(cy + r * .8)]]); break;
      case "fan": for (let i = 0; i < 3; i++) { const a = i * 2.094; dc.fillCircle(t(cx + Math.cos(a) * r * .5), t(cy + Math.sin(a) * r * .5), t(r * .45)); } dc.setColor(T.BLACK); dc.fillCircle(cx, cy, Math.max(1, t(r * .18))); break;
      case "pin": dc.fillCircle(cx, t(cy - r * .25), t(r * .65)); dc.fillPolygon([[t(cx - r * .55), t(cy - r * .05)], [t(cx + r * .55), t(cy - r * .05)], [cx, t(cy + r)]]); dc.setColor(T.BLACK); dc.fillCircle(cx, t(cy - r * .25), Math.max(1, t(r * .25))); break;
      case "list": for (let i = -1; i <= 1; i++) dc.fillRectangle(t(cx - r), t(cy + i * r * .65 - r * .15), t(r * 2), Math.max(2, t(r * .3))); break;
      case "gear": dc.fillCircle(cx, cy, t(r * .7)); for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3; dc.fillCircle(t(cx + Math.cos(a) * r * .8), t(cy + Math.sin(a) * r * .8), Math.max(1, t(r * .25))); } dc.setColor(T.BLACK); dc.fillCircle(cx, cy, Math.max(1, t(r * .3))); break;
      case "stop": dc.fillRoundedRectangle(t(cx - r * .75), t(cy - r * .75), t(r * 1.5), t(r * 1.5), 2); break;
      case "refresh": dc.drawArc(cx, cy, t(r * .75), -60, 240); dc.fillPolygon([[t(cx + r * .2), t(cy - r * 1.05)], [t(cx + r * .95), t(cy - r * .65)], [t(cx + r * .2), t(cy - r * .2)]]); break;
      case "check": dc.setPenWidth(Math.max(2, t(r / 2.5))); dc.drawLine(t(cx - r * .8), t(cy), t(cx - r * .2), t(cy + r * .6)); dc.drawLine(t(cx - r * .2), t(cy + r * .6), t(cx + r * .85), t(cy - r * .6)); break;
      case "cross": dc.setPenWidth(Math.max(2, t(r / 2.5))); dc.drawLine(t(cx - r * .7), t(cy - r * .7), t(cx + r * .7), t(cy + r * .7)); dc.drawLine(t(cx + r * .7), t(cy - r * .7), t(cx - r * .7), t(cy + r * .7)); break;
      case "bang": dc.fillRectangle(t(cx - r * .17), t(cy - r), Math.max(2, t(r * .34)), t(r * 1.25)); dc.fillRectangle(t(cx - r * .17), t(cy + r * .55), Math.max(2, t(r * .34)), Math.max(2, t(r * .38))); break;
      case "plus": dc.fillRectangle(t(cx - r), t(cy - r * .18), t(r * 2), Math.max(2, t(r * .36))); dc.fillRectangle(t(cx - r * .18), t(cy - r), Math.max(2, t(r * .36)), t(r * 2)); break;
      case "minus": dc.fillRectangle(t(cx - r), t(cy - r * .18), t(r * 2), Math.max(2, t(r * .36))); break;
      case "menu": for (let i = -1; i <= 1; i++) dc.fillCircle(cx, t(cy + i * r * .7), Math.max(1, t(r * .22))); break;
      case "map": dc.fillPolygon([[t(cx - r), t(cy - r * .7)], [t(cx - r * .33), t(cy - r)], [t(cx + r * .33), t(cy - r * .7)], [t(cx + r), t(cy - r)], [t(cx + r), t(cy + r * .7)], [t(cx + r * .33), t(cy + r)], [t(cx - r * .33), t(cy + r * .7)], [t(cx - r), t(cy + r)]]); dc.setColor(T.BLACK); dc.setPenWidth(1); dc.drawLine(t(cx - r * .33), t(cy - r), t(cx - r * .33), t(cy + r * .7)); dc.drawLine(t(cx + r * .33), t(cy - r * .7), t(cx + r * .33), t(cy + r)); break;
      case "thermo": dc.fillRoundedRectangle(t(cx - r * .22), t(cy - r), t(r * .44), t(r * 1.3), t(r * .22)); dc.fillCircle(cx, t(cy + r * .55), t(r * .45)); break;
      default: Icons.draw(dc, "unknown", cx, cy, r, color);
    }
    dc.setPenWidth(1);
  }
};

// ---------------------------------------------------------------- Ui helpers (NEW only)
const NUMBER_GLYPHS = " #%+-./0123456789:°";
const Ui = {
  isNumberGlyphs(s) { return [...String(s)].every(ch => NUMBER_GLYPHS.includes(ch)); },
  usable(top, bottom, margin = 8) { return Math.max(0, TB.lineWidth(R, 130, top, bottom) - 2 * (margin - 8)); },
  fit(dc, text, font, maxW) { let s = String(text); if (dc.getTextWidthInPixels(s, font) <= maxW) return s; while (s.length > 1 && dc.getTextWidthInPixels(s + "…", font) > maxW) s = s.slice(0, -1); return s.replace(/\s+$/, "") + "…"; },
  wrap(dc, text, font, widths, maxLines = widths.length) {
    let lines = TB.wrap(String(text), widths, s => dc.getTextWidthInPixels(s, font));
    if (lines.length > maxLines) { lines = lines.slice(0, maxLines); const i = maxLines - 1; lines[i] = Ui.fit(dc, lines[i] + "…", font, widths[Math.min(i, widths.length - 1)]); }
    return lines;
  },
  // Accent title, tiny font, top at y; fitted to the chord at that height.
  title(dc, text, y = 34) { const h = FM.tiny.h; const s = Ui.fit(dc, text, "tiny", Ui.usable(y, y + h)); dc.setColor(T.ACCENT); dc.drawText(130, y, "tiny", s, J.CENTER); const w = dc.getTextWidthInPixels(s, "tiny"); return { x: 130 - w / 2, y, w, h }; },
  // Digits (and % °) in a number font, unit in a text font, baselines aligned. y = top of the number box.
  drawValueWithUnit(dc, cx, y, value, unit, o = {}) {
    const num = o.num || "numMed", uf = o.unitFont || "medium", gap = o.gap == null ? 4 : o.gap;
    if (!Ui.isNumberGlyphs(value)) throw new Error("drawValueWithUnit: '" + value + "' has characters the number font lacks");
    const wv = dc.getTextWidthInPixels(value, num), wu = unit ? dc.getTextWidthInPixels(unit, uf) : 0, total = wv + (unit ? gap + wu : 0);
    const x0 = Math.round(cx - total / 2);
    dc.setColor(o.color || T.TEXT_1); dc.drawText(x0, y, num, value, J.LEFT);
    if (unit) { dc.setColor(o.unitColor || T.TEXT_2); dc.drawText(x0 + wv + gap, y + FM[num].asc - FM[uf].asc, uf, unit, J.LEFT); }
    return { x: x0, y, w: total, h: FM[num].h };
  },
  // Hero: either a word (FONT_MEDIUM, white) with an optional icon in front, or a number with unit.
  drawHero(dc, o) {
    const cx = o.cx || 130;
    if (o.word != null) {
      const f = o.font || "medium", w = dc.getTextWidthInPixels(o.word, f), iw = o.icon ? 2 * (o.iconR || 12) + 8 : 0, x0 = Math.round(cx - (w + iw) / 2);
      if (o.icon) NIcons.draw(dc, o.icon, x0 + (o.iconR || 12), o.y + Math.round(FM[f].h / 2), o.iconR || 12, o.color || T.TEXT_1);
      dc.setColor(o.color || T.TEXT_1); dc.drawText(x0 + iw, o.y, f, o.word, J.LEFT);
      return { x: x0, y: o.y, w: w + iw, h: FM[f].h };
    }
    return Ui.drawValueWithUnit(dc, cx, o.y, o.value, o.unit, o);
  },
  chipWidth(dc, c) { const f = c.font || "xtiny"; const icon = c.icon || (c.kind === "warn" || c.kind === "error" ? "bang" : null); return 16 + (icon ? 14 : 0) + dc.getTextWidthInPixels(c.text, f); },
  // Chip: pill with icon + one word. y = top. kinds: outline | warn | error | accent | white
  drawChip(dc, cx, y, c) {
    const h = c.h || 20, f = c.font || "xtiny", kind = c.kind || "outline", w = Ui.chipWidth(dc, c), x = Math.round(cx - w / 2);
    const icon = c.icon || (kind === "warn" || kind === "error" ? "bang" : null);
    const fill = { warn: T.WARNING, error: T.DESTRUCTIVE, accent: T.ACCENT, white: T.TEXT_1 }[kind];
    let fg = T.TEXT_1;
    if (fill) { dc.setColor(fill); dc.fillRoundedRectangle(x, y, w, h, h / 2); fg = T.BLACK; }
    else { dc.setColor(T.RULE); dc.setPenWidth(1); dc.drawRoundedRectangle(x, y, w, h, h / 2); }
    let tx = x + 8;
    if (icon) { NIcons.draw(dc, icon, tx + 6, y + h / 2, 6, fg); tx += 14; }
    dc.setColor(fg); dc.drawText(tx, y + Math.round(h / 2), f, c.text, J.LEFT | J.VCENTER);
    return { x, y, w, h };
  },
  drawChipRow(dc, y, chips, gap = 6) {
    const ws = chips.map(c => Ui.chipWidth(dc, c)), total = ws.reduce((a, b) => a + b, 0) + gap * (chips.length - 1);
    let x = 130 - total / 2; chips.forEach((c, i) => { Ui.drawChip(dc, x + ws[i] / 2, y, c); x += ws[i] + gap; });
    return { x: 130 - total / 2, y, w: total, h: chips[0] && chips[0].h || 20 };
  },
  // Focused row: accent pill, black label; falls back to small when the label is too wide.
  focusPill(dc, x, y, w, h, label, font = "medium") {
    dc.setColor(dc.mono ? T.TEXT_1 : T.ACCENT); dc.fillRoundedRectangle(x, y, w, h, h / 2);
    let f = font; if (dc.getTextWidthInPixels(label, f) > w - 16) f = "small"; if (dc.getTextWidthInPixels(label, f) > w - 16) f = "tiny";
    dc.setColor(T.BLACK); dc.drawText(x + w / 2, y + Math.round(h / 2), f, Ui.fit(dc, label, f, w - 16), J.CENTER | J.VCENTER);
    return { x, y, w, h };
  },
  // Ring around the bezel from 12 o'clock clockwise.
  drawRing(dc, frac, o = {}) {
    const r = o.r || 126, pen = o.pen || 4;
    dc.setPenWidth(pen); dc.setColor(o.track || T.RULE); dc.drawArc(130, 130, r, 0, 360);
    if (frac > 0) { dc.setColor(o.fill || T.TEXT_1); dc.drawArc(130, 130, r, -90, -90 + 360 * Math.min(1, frac)); }
    if (o.tick != null) { const a = (-90 + 360 * o.tick) * Math.PI / 180; dc.setPenWidth(2); dc.setColor(o.tickColor || T.TEXT_1); dc.drawLine(130 + Math.cos(a) * (r - 7), 130 + Math.sin(a) * (r - 7), 130 + Math.cos(a) * (r + 3), 130 + Math.sin(a) * (r + 3)); }
    dc.setPenWidth(1);
  },
  // Personality-style hint arc at a button: 4 px band r 124..128, ±10° around the button.
  drawHintArc(dc, pos, kind = "dark") {
    dc.setColor({ dark: T.TEXT_1, accent: T.ACCENT, positive: "#00AA00", destructive: T.DESTRUCTIVE }[kind] || T.TEXT_1);
    dc.arcBand(130, 130, 124, 128, BTN[pos] - 10, BTN[pos] + 10);
  },
  // Small glyph inside the bezel next to a button (r 108), plus its hint arc.
  drawBezelGlyph(dc, pos, glyph, color = T.TEXT_2, arc = "dark") {
    const a = BTN[pos] * Math.PI / 180, x = Math.round(130 + Math.cos(a) * 108), y = Math.round(130 + Math.sin(a) * 108);
    NIcons.draw(dc, glyph, x, y, 6, color); if (arc) Ui.drawHintArc(dc, pos, arc);
    return { x: x - 6, y: y - 6, w: 12, h: 12 };
  },
  drawPageIndicator(dc, idx, count, style = "arc") {
    if (style === "arc") { Native.pageIndicatorArc(dc, idx, count); return; }
    for (let i = 0; i < count; i++) {
      const a = (180 + ((count - 1) / 2 - i) * 7.5) * Math.PI / 180, x = Math.round(130 + Math.cos(a) * 118), y = Math.round(130 + Math.sin(a) * 118);
      if (i === idx) { dc.setColor(T.ACCENT); dc.fillCircle(x, y, 4); } else { dc.setColor(T.RULE); dc.fillCircle(x, y, 3); }
    }
  },
  // Scroll position on the right bezel: track ±15° at r 126, thumb sized visible/total.
  drawScrollArc(dc, first, visible, total) {
    if (total <= visible) return;
    const span = 30, a0 = -span / 2, thumb = span * visible / total, start = a0 + span * first / total;
    dc.setPenWidth(3); dc.setColor(T.RULE); dc.drawArc(130, 130, 126, a0, a0 + span);
    dc.setColor(T.TEXT_2); dc.drawArc(130, 130, 126, start, start + thumb); dc.setPenWidth(1);
  },
  // Age line: xtiny grey, or amber "! 17 h ago" in tiny when stale. y = top.
  drawAge(dc, y, min, o = {}) {
    if (Age.stale(min)) { const s = "! " + (o.short ? Age.short(min) : Age.text(min)); dc.setColor(T.WARNING); dc.drawText(130, y - 2, "tiny", s, J.CENTER); return { y: y - 2, h: FM.tiny.h }; }
    const s = o.prefix ? o.prefix + Age.text(min) : (o.short ? Age.short(min) : Age.text(min));
    dc.setColor(T.TEXT_2); dc.drawText(130, y, "xtiny", s, J.CENTER); return { y, h: FM.xtiny.h };
  }
};

// ---------------------------------------------------------------- Garmin native UI (fēnix 7 Pro device files)
// Used by OLD and NEW alike. Always white on black; Menu2 themes are not supported on this watch.
const Native = {
  hintArc(dc, pos, color = T.TEXT_1) { dc.setColor(color); dc.arcBand(130, 130, 124, 128, BTN[pos] - 10, BTN[pos] + 10); },
  // simulator.json layouts.menu2: title 78, focused row 87 (label small, sub tiny), neighbours 55 (tiny),
  // 3 x 57 focus bar at x 13. Focused row is centred on y 130.
  menu2(dc, o) {
    const items = o.items, focus = o.focus || 0;
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const fTop = 130 - 43;
    const label = it => String(it.label).replace(/\n/g, " ");
    // title block sits directly above the first item
    let y = fTop; for (let i = focus - 1; i >= 0; i--) y -= 55;
    const titleTop = y - 78;
    if (o.title && titleTop + 25 >= 6) { dc.setColor(T.TEXT_1); dc.drawText(130, titleTop + 39, "tiny", Ui.fit(dc, o.title, "tiny", Ui.usable(titleTop + 25, titleTop + 54)), J.CENTER | J.VCENTER); dc.setColor(T.RULE); dc.fillRectangle(40, titleTop + 76, 180, 1); }
    let yy = titleTop + 78;
    items.forEach((it, i) => {
      const focused = i === focus, h = focused ? 87 : 55, mid = yy + h / 2;
      if (yy < 260 && yy + h > 0) {
        const hasIcon = !!it.icon, xL = focused ? 23 + 8 : 0;
        if (focused) {
          dc.setColor(T.TEXT_1); dc.fillRectangle(13, mid - 28, 3, 57);
          let x = 30; if (hasIcon) { NIcons.draw(dc, it.icon, 50, mid, 10, it.iconColor || T.TEXT_1); x = 70; }
          const maxW = (it.toggle != null || it.check != null ? 196 : 226) - x;
          dc.setColor(T.TEXT_1); dc.drawText(x, it.sub ? mid - 13 : mid, "small", Ui.fit(dc, label(it), "small", maxW), J.LEFT | J.VCENTER);
          if (it.sub) { dc.setColor(T.TEXT_2); dc.drawText(x, mid + 17, "tiny", Ui.fit(dc, it.sub, "tiny", maxW), J.LEFT | J.VCENTER); }
          if (it.toggle != null) Native._toggle(dc, 214, mid, it.toggle);
          if (it.check != null) Native._check(dc, 214, mid, it.check);
        } else {
          const w = Ui.usable(mid - 14, mid + 14) - (hasIcon ? 26 : 0);
          // A row that only peeks past the edge shows no label (the watch shows just the edge of the row).
          if (w < Math.min(80, dc.getTextWidthInPixels(label(it), "tiny"))) { yy += h; return; }
          const s = Ui.fit(dc, label(it), "tiny", Math.min(193, w)), sw = dc.getTextWidthInPixels(s, "tiny") + (hasIcon ? 26 : 0), x0 = 130 - sw / 2;
          if (hasIcon) NIcons.draw(dc, it.icon, x0 + 9, mid, 8, T.TEXT_2);
          dc.setColor(T.TEXT_2); dc.drawText(x0 + (hasIcon ? 26 : 0), mid, "tiny", s, J.LEFT | J.VCENTER);
        }
      }
      yy += h;
    });
  },
  _toggle(dc, cx, cy, on) { dc.setColor(on ? "#00FF00" : T.TEXT_2); dc.fillRoundedRectangle(cx - 5, cy - 25, 9, 50, 4); dc.setColor(T.TEXT_1); dc.fillRoundedRectangle(cx - 3, on ? cy - 23 : cy + 5, 5, 18, 2); },
  _check(dc, cx, cy, on) { dc.setColor(T.RULE); dc.setPenWidth(2); dc.drawRectangle(cx - 15, cy - 15, 30, 30); dc.setPenWidth(1); if (on) NIcons.draw(dc, "check", cx, cy, 12, "#00FF00"); },
  // personality.mss confirmation: body (52,52,156,156) FONT_TINY; confirm hint at START, reject at DOWN.
  confirmation(dc, text) {
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const lines = Ui.wrap(dc, text, "tiny", [156], 5), lh = FM.tiny.h, top = 130 - Math.floor(lines.length * lh / 2);
    dc.setColor(T.TEXT_1); lines.forEach((l, i) => dc.drawText(130, top + i * lh, "tiny", l, J.CENTER));
    Native.hintArc(dc, "start"); NIcons.draw(dc, "check", 222, 76, 10, "#00FF00");
    Native.hintArc(dc, "down"); NIcons.draw(dc, "cross", 38, 184, 8, T.DESTRUCTIVE);
  },
  // simulator.json toast: partial banner from the top, icon 40 at y 26, one line of small text.
  toast(dc, under, o) {
    under(dc);
    dc.setColor(T.BG); dc.fillRectangle(0, 0, 260, 124); dc.setColor(T.RULE); dc.fillRectangle(30, 124, 200, 1);
    if (o.icon) NIcons.draw(dc, o.icon, 130, 46, 14, o.icon === "check" ? "#00FF00" : o.icon === "bang" ? T.WARNING : T.TEXT_1);
    dc.setColor(T.TEXT_1); dc.drawText(130, 92, "small", Ui.fit(dc, o.text, "small", Ui.usable(76, 108)), J.CENTER | J.VCENTER);
  },
  // simulator.json actionMenu: panel x 147..260, 2 px white left border, entries x 12 (panel), selected at y 119.
  actionMenu(dc, under, o) {
    under(dc);
    dc.setColor(T.BG); dc.fillRectangle(147, 0, 113, 260); dc.setColor(T.TEXT_1); dc.fillRectangle(147, 0, 2, 260);
    const f = o.focus || 0;
    dc.fillRectangle(152, 111, 4, 42);
    o.items.forEach((it, i) => {
      const y = 132 + (i - f) * 25; if (y < 10 || y > 250) return;
      const maxW = Math.max(0, Math.min(100, 130 + Math.floor(Math.sqrt(Math.max(0, 130 * 130 - (y - 130) * (y - 130)))) - 8 - 159));
      dc.setColor(i === f ? T.TEXT_1 : T.TEXT_2); dc.drawText(159, y, "xtiny", Ui.fit(dc, it, "xtiny", maxW), J.LEFT | J.VCENTER);
    });
  },
  // ViewLoop page indicator: type arc on the left. 6° segments, 2° gaps at r 120, filled white; current black with white outline.
  pageIndicatorArc(dc, idx, count) {
    for (let i = 0; i < count; i++) {
      const mid = 180 + ((count - 1) / 2 - i) * 8;
      dc.setColor(T.TEXT_1); dc.arcBand(130, 130, 116, 124, mid - 3, mid + 3);
      if (i === idx) { dc.setColor(T.BLACK); dc.arcBand(130, 130, 117.5, 122.5, mid - 2, mid + 2); }
    }
  }
};

// ---------------------------------------------------------------- NEW menus in Škoda green
// Menu2 cannot be recoloured on the fēnix 7 Pro (themes unsupported), so the NEW design draws its menus
// itself: on the watch this is a WatchUi.CustomMenu with CustomMenuItem.draw(), which keeps Garmin's own
// scrolling, focus animation and key/touch handling. Same geometry as Menu2 (title 78, focused 87, rows 55).
Ui.menu = function (dc, o) {
  // Mirrors app/source/ui/NightMenu.mc: rows of 65 px (Ui.ROW_H), and only the focused row and one
  // above and one below are drawn (NightMenuLayout.isShown), so three sit close together in the
  // middle and the rest stays off screen. The title is the platform's 78 px area directly above
  // row 0 and counts as row -1. The pill follows its text and sits centred.
  // o.shift (px) moves every row during the simulator's slide (Ui.slideShift). The row leaving the
  // screen is not drawn, as in the app (its focus has already moved): sliding out it would pass
  // through the round edge with its text cut. The row coming in slides into place.
  const H = Ui.ROW_H, items = o.items, focus = o.focus || 0, shift = o.shift || 0, label = it => String(it.label).replace(/\n/g, " ");
  dc.setColor(T.TEXT_1, T.BG); dc.clear();
  const titleBottom = 130 - Math.floor(H / 2) - focus * H + shift;
  if (o.title && focus === 0 && titleBottom - 78 / 2 - 14 >= 6) {
    const cy = titleBottom - 39;
    dc.setColor(T.ACCENT); dc.drawText(130, cy, "tiny", Ui.fit(dc, o.title, "tiny", Ui.usable(cy - 14, cy + 15)), J.CENTER | J.VCENTER);
    dc.setColor(T.RULE); dc.fillRectangle(60, titleBottom - 2, 140, 1);
  }
  for (let i = Math.max(0, focus - 1); i <= Math.min(items.length - 1, focus + 1); i++) {
    const it = items[i], cy = Math.round(130 + (i - focus) * H + shift);
    if (i === focus) {
      const ph = Math.min(it.sub ? FM.small.h + FM.xtiny.h + 14 : FM.medium.h + 14, H - 6), px = 24, pw = 212, py = Math.round(cy - ph / 2);
      dc.setColor(dc.mono ? T.TEXT_1 : T.ACCENT); dc.fillRoundedRectangle(px, py, pw, ph, ph / 2);
      const right = it.toggle != null || it.check != null ? 34 : 0;
      let x = px + 20; if (it.icon) { NIcons.draw(dc, it.icon, x + 8, cy, 9, T.BLACK); x += 26; }
      const maxW = px + pw - 20 - right - x;
      let f = it.sub ? "small" : "medium"; if (dc.getTextWidthInPixels(label(it), f) > maxW) f = it.sub ? "tiny" : "small"; if (dc.getTextWidthInPixels(label(it), f) > maxW) f = "tiny";
      dc.setColor(T.BLACK); dc.drawText(x, it.sub ? cy - Math.round(ph / 5) : cy, f, Ui.fit(dc, label(it), f, maxW), J.LEFT | J.VCENTER);
      if (it.sub) { dc.setColor(dc.mono ? T.BLACK : T.EMERALD); dc.drawText(x, cy + Math.round(ph / 4), "xtiny", Ui.fit(dc, it.sub, "xtiny", maxW), J.LEFT | J.VCENTER); }
      if (it.check) NIcons.draw(dc, "check", px + pw - 30, cy, 9, T.BLACK);
    } else {
      const block = FM.tiny.h + (it.sub ? FM.xtiny.h : 0);
      const iconW = it.icon ? 26 : 0, at = 130 + (i - focus) * H, maxW = Math.min(193, Ui.usable(at - block / 2, at + block / 2, 8)) - iconW;   // fitted where it settles, as in the app
      const s1 = Ui.fit(dc, label(it), "tiny", maxW), s2 = it.sub ? Ui.fit(dc, it.sub, "xtiny", maxW) : null;
      const tw = Math.max(dc.getTextWidthInPixels(s1, "tiny"), s2 ? dc.getTextWidthInPixels(s2, "xtiny") : 0) + iconW, x0 = Math.round(130 - tw / 2);
      const top = Math.round(cy - block / 2);
      if (it.icon) NIcons.draw(dc, it.icon, x0 + 9, cy, 8, T.ACCENT);
      dc.setColor(T.TEXT_2); dc.drawText(x0 + iconW, top + Math.round(FM.tiny.h / 2), "tiny", s1, J.LEFT | J.VCENTER);
      if (s2) dc.drawText(x0 + iconW, top + FM.tiny.h + Math.round(FM.xtiny.h / 2), "xtiny", s2, J.LEFT | J.VCENTER);
    }
  }
};
// Row pitch of every NEW list (Theme.rowHeight(): a quarter of the 260 px display).
Ui.ROW_H = 65;
// Slide between two focus positions, like the CustomMenu's own scroll: the rows start where they
// were (one row back) and ease into place. slide = {d: +1 DOWN / -1 UP, t0}; 0 when done or absent.
Ui.SLIDE_MS = 180;
Ui.slideShift = function (slide, now) {
  if (!slide || !(Ui.SLIDE_MS > 0)) return 0;
  const t = Math.min(1, (now - slide.t0) / Ui.SLIDE_MS);
  return t >= 1 ? 0 : slide.d * Ui.ROW_H * Math.pow(1 - t, 2);
};
// Action menu in Škoda green. Garmin's ActionMenu (a panel over the right half) cannot be recoloured and
// cuts through the screen behind it, so the NEW design shows the actions as a full-screen Ui.menu instead.
// On the watch: a CustomMenu pushed with SLIDE_LEFT. `under` is kept in the signature but not drawn.
const ACTION_ICONS = { Refresh: "refresh", Navigate: "pin", "Navigate to car": "pin", "Charge limit": "battery", "Charging profiles": "list", Charging: "bolt", Settings: "gear", Status: "list" };
Ui.actionMenu = function (dc, under, o) {
  Ui.menu(dc, { title: o.title || "Actions", items: o.items.map(l => ({ label: l, icon: ACTION_ICONS[l] })), focus: o.focus || 0 });
};

// ---------------------------------------------------------------- registries
// OLD_SCREENS: filled by 20-old.js (id -> {section, order, name, draw, keys, src, tags, notes}).
// CARDS: each NEW part pushes {id, section, order, name, neu:[{label, draw, keys, decision}], fixes, changed, notes}.
//   A card whose id matches an OLD_SCREENS id is shown next to that old screen; otherwise it is new-only.
// SIM_VIEWS: name -> {init(o) -> state, draw(dc, state), key(k, state) -> null | {push, o} | {pop:true} |
//   {toast:{text, icon}} | {confirm:{text, then}} | {replace, o}}; k in UP DOWN START BACK MENU SWIPE_UP SWIPE_DOWN TAP.
const OLD_SCREENS = {};
const CARDS = [];
const SIM_VIEWS = {};
const SECTION_ORDER = ["entry", "home", "status", "charging", "findcar", "settings", "onboarding", "garmin"];


