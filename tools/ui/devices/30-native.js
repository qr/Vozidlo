// ================================================================ DEVICES: Garmin UI per watch (approximate)
// Garmin draws these itself; the app only chooses text and icon. On the fēnix the poc's Native.* is drawn
// from the device files. On the AMOLED watches the device files give fonts and areas but not every
// position, so these are stand-ins: good enough to see what lands where, not pixel truth.
const DevNative = (function () {
  // Confirmation: check at START, cross at the reject button (DOWN on the fēnix, BACK on two-button watches).
  function confirmation(dc, G, text) {
    if (G.P.five) { Native.confirmation(dc, text); return; }
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const lines = Ui.wrap(dc, text, "tiny", [156], 5), lh = FM.tiny.h, top = 130 - Math.floor(lines.length * lh / 2);
    dc.setColor(T.TEXT_1); lines.forEach((l, i) => dc.drawText(130, top + i * lh, "tiny", l, J.CENTER));
    const [sx, sy] = G.anchor("start", 96), [bx, by] = G.anchor("back", 96);
    G.hintArc(dc, "start", "positive"); NIcons.draw(dc, "check", sx, sy, 10, "#00FF00");
    G.hintArc(dc, "back", "destructive"); NIcons.draw(dc, "cross", bx, by, 8, T.DESTRUCTIVE);
  }
  // Toast: partial banner from the top edge of the frame; its text is fitted 12 px inside the outline.
  function toast(dc, G, under, o) {
    under(dc);
    if (!G.round) { dc.setColor(T.BG); dc.fillRectangle(0, G.top, 260, -G.top); }
    const usable = Ui.usable; Ui.usable = (t, b, m = 8) => usable(t, b, Math.max(m, 12));
    try { Native.toast(dc, () => {}, o); } finally { Ui.usable = usable; }
  }
  // Glance: drawn at device px (render option raw), so paddings scale with s while fonts are the device's.
  // Rows stack by font height and centre in the content area (GlanceView, laid out from the Dc).
  function glance(dc, P, o = {}) {
    const s = P.s, [gx, , gw, gh] = P.glance, gy = Math.round((P.h - gh) / 2);   // the focused glance sits in the middle of the list
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const c = dc.c;
    // neighbouring glances and separators (the watch's own chrome, approximate)
    c.globalAlpha = .35; dc.setColor(T.RULE);
    const above = gy - gh * 0.55, below = gy + gh * 1.55;
    dc.fillCircle(gx * 0.55, above, P.launcher * 0.4); dc.fillCircle(gx * 0.55, below, P.launcher * 0.4);
    dc.setColor(T.TEXT_2); dc.drawText(gx + 6 * s, above - FM.xtiny.h / 2, "xtiny", "Body Battery", J.LEFT); dc.drawText(gx + 6 * s, below - FM.xtiny.h / 2, "xtiny", "Weather", J.LEFT);
    c.globalAlpha = 1;
    if (P.shape === "round" || !P.five) { dc.setColor(T.RULE); dc.fillRectangle(gx * 0.4, gy - 2, P.w - gx * 0.8, 1); dc.fillRectangle(gx * 0.4, gy + gh + 2, P.w - gx * 0.8, 1); }
    const k = P.launcher / 40; NG.appIcon(dc, gx * 0.5 - P.launcher / 2, gy + gh / 2 - P.launcher / 2, k);
    dc.translate(gx, gy); dc.setClip(0, 0, gw, gh);
    const X = Math.round(6 * s), barH = Math.max(4, Math.round(4 * s));
    const rowsH = FM.xtiny.h + 1 + FM.tiny.h + Math.round(6 * s) + barH, y1 = Math.max(Math.round(2 * s), Math.round((gh - rowsH) / 2));
    dc.setColor(T.TEXT_2); dc.drawText(X, y1, "xtiny", "Vozidlo", J.LEFT);
    const y2 = y1 + FM.xtiny.h + 1;
    if (!o.data) { const t = "Open for your car", f = dc.getTextWidthInPixels(t, "tiny") <= gw - 2 * X ? "tiny" : "xtiny"; dc.drawText(X, y2, f, Ui.fit(dc, t, f, gw - 2 * X), J.LEFT); }
    else {
      dc.drawText(gw - X, y1, "xtiny", Age.short(NMOCK.ageMin), J.RIGHT);
      const soc = NMOCK.soc + "%", mid = y2 + Math.round(FM.tiny.h / 2), r = Math.round(8 * s);
      dc.setColor(T.TEXT_1); dc.drawText(X, y2, "tiny", soc, J.LEFT);
      let x = X + dc.getTextWidthInPixels(soc, "tiny") + Math.round(13 * s);
      NIcons.draw(dc, "locked", x, mid, r, T.TEXT_1); x += Math.round(11 * s);
      dc.setColor(T.TEXT_1); dc.drawText(x, y2, "tiny", Labels.lock(NMOCK.lock), J.LEFT);
      x += dc.getTextWidthInPixels(Labels.lock(NMOCK.lock), "tiny") + Math.round(12 * s);
      NIcons.draw(dc, "pluggedIn", x, mid, r, T.TEXT_1);
      const by = y2 + FM.tiny.h + Math.round(6 * s), bw = gw - 2 * X, fw = Math.round(bw * NMOCK.soc / 100);
      if (fw < bw) { dc.setColor(T.RULE); dc.fillRectangle(X + fw, by, bw - fw, barH); }
      dc.setColor(T.TEXT_1); dc.fillRectangle(X, by, fw, barH);
    }
    dc.clearClip(); dc.translate(-gx, -gy);
  }
  return { confirmation, toast, glance };
})();
