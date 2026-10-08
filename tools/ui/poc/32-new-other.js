// ================================================================ NEW find my car, settings, glance, onboarding, Garmin UI (agent D)
(function () {
  const NF = {}, NG = {}, NSet = {}, NO = {}, NGUI = {};
  const t = Math.trunc;
  const blank = dc => { dc.setColor(T.TEXT_1, T.BG); dc.clear(); };
  // Native.menu2 wrapped in a clip y 2..240: rows that only peek past the circle edge are not drawn
  // (core menu2 would otherwise draw them as a one-letter "F…").
  const menu2 = (dc, o) => { blank(dc); dc.setClip(0, 2, 260, 238); Native.menu2(dc, o); dc.clearClip(); };
  // NEW menus: CustomMenu in Škoda green (Menu2 itself cannot be recoloured on the fēnix 7 Pro).
  const nmenu = (dc, o) => { blank(dc); dc.setClip(0, 2, 260, 238); Ui.menu(dc, o); dc.clearClip(); };

  // ============================================================== NF: find my car (C5)
  const EX = { dist: "240", unit: "m", bearing: 35 };      // Example values
  const rad = deg => deg * Math.PI / 180;
  const polar = (r, deg) => [Math.round(130 + Math.cos(rad(deg)) * r), Math.round(130 + Math.sin(rad(deg)) * r)];

  // Ring track r 125; bearing pointer: accent wedge on the ring, apex outward (no accent ring segment,
  // so it never merges with the accent START arc when the car is to the upper right). Outline only without a heading.
  NF.ring = function (dc) { dc.setPenWidth(3); dc.setColor(T.RULE); dc.drawArc(130, 130, 125, 0, 360); dc.setPenWidth(1); };
  NF.pointer = function (dc, bearing, hasHeading) {
    const a = bearing - 90;                       // compass degrees -> canvas degrees
    const tip = polar(128, a), l = polar(110, a - 7), r = polar(110, a + 7);
    dc.setColor(T.ACCENT);
    if (hasHeading) {
      dc.fillPolygon([tip, l, r]);
    } else {
      dc.setPenWidth(2); dc.drawLine(tip[0], tip[1], l[0], l[1]); dc.drawLine(l[0], l[1], r[0], r[1]); dc.drawLine(r[0], r[1], tip[0], tip[1]); dc.setPenWidth(1);
    }
  };
  // Address in xtiny, two lines wrapped to [158, 186] with "…".
  NF.address = function (dc, y0, color = T.TEXT_1) {
    const lines = Ui.wrap(dc, NMOCK.address, "xtiny", [158, 186], 2);
    dc.setColor(color); lines.forEach((l, i) => dc.drawText(130, y0 + i * 19, "xtiny", l, J.CENTER));
  };
  NF.parked = function (dc, o = {}) {
    blank(dc);
    NF.ring(dc);
    NF.address(dc, 46);
    Ui.drawValueWithUnit(dc, 130, 88, EX.dist, EX.unit);
    Ui.drawAge(dc, 172, o.age != null ? o.age : NMOCK.ageMin);
    NF.pointer(dc, EX.bearing, o.heading !== false);
    Ui.drawHintArc(dc, "start", "accent");          // START = map
  };
  NF.gps = function (dc) {
    blank(dc); NF.ring(dc); NF.address(dc, 46);
    dc.setColor(T.TEXT_2); dc.drawText(130, 112, "small", "Waiting for GPS", J.CENTER);
    Ui.drawAge(dc, 172, NMOCK.ageMin);
  };
  NF.moving = function (dc) {
    blank(dc); NF.ring(dc);
    Ui.drawHero(dc, { word: "Car is moving", y: 90 });
    dc.setColor(T.TEXT_2); dc.drawText(130, 130, "xtiny", "Last parked", J.CENTER);
    NF.address(dc, 150);
    Ui.drawAge(dc, 196, NMOCK.ageMin);
  };
  NF.MENU_ITEMS = ["Navigate", "Refresh"];
  NF.menu = function (dc, focus = 0) { Ui.actionMenu(dc, d => NF.parked(d), { items: NF.MENU_ITEMS, focus }); };
  NF.NAV_TEXT = "Navigate to the car? This closes the app.";
  NF.nav = function (dc) { Native.confirmation(dc, NF.NAV_TEXT); };

  // Map stand-in: the tiles and the pins are Garmin's MapView (MAP_MODE_PREVIEW, MAP_MARKER_ICON_PIN).
  // Same look as the OLD stand-in; the park green is 0xAAFF55 because 0xAAFFAA is on the banned list.
  NF.map = function (dc, o = {}) {
    const c = dc.c; dc.setColor(T.TEXT_1, T.BG); dc.clear();
    c.fillStyle = "#FFFFAA"; c.fillRect(0, 0, 260, 260);
    c.fillStyle = "#AAFF55"; c.beginPath(); c.moveTo(20, 30); c.lineTo(110, 18); c.lineTo(120, 92); c.lineTo(36, 110); c.closePath(); c.fill();
    c.fillStyle = "#AAFFFF"; c.beginPath(); c.ellipse(205, 210, 60, 26, -0.4, 0, Math.PI * 2); c.fill();
    c.strokeStyle = "#FFFFFF"; c.lineWidth = 9; c.beginPath(); c.moveTo(-10, 150); c.lineTo(270, 120); c.moveTo(150, -10); c.lineTo(170, 270); c.stroke();
    c.strokeStyle = "#AAAAAA"; c.lineWidth = 1; c.beginPath(); c.moveTo(-10, 150); c.lineTo(270, 120); c.moveTo(150, -10); c.lineTo(170, 270); c.stroke();
    c.strokeStyle = "#FFFFFF"; c.lineWidth = 4; c.beginPath(); c.moveTo(60, 270); c.lineTo(120, 140); c.moveTo(165, 60); c.lineTo(260, 70); c.stroke();
    const pin = (x, y, label) => { dc.setColor("#FF0000"); dc.fillCircle(x, y - 14, 8); dc.fillPolygon([[x - 6, y - 10], [x + 6, y - 10], [x, y]]); dc.setColor("#FFFFFF"); dc.fillCircle(x, y - 14, 3); dc.setColor("#000000"); dc.drawText(x, y + 2, "xtiny", label, J.CENTER); };
    pin(130, 136, "Car"); pin(96, 196, "You");
    if (o.browse) {   // stand-in for Garmin's own browse controls
      dc.setColor(T.BG); dc.fillRoundedRectangle(70, 30, 120, 24, 12);
      dc.setColor(T.TEXT_1); dc.drawText(130, 42, "xtiny", "Browse: pan / zoom", J.CENTER | J.VCENTER);
    }
  };
  NF.MAP_MENU = { title: "Map", items: [{ label: "Navigate to car" }] };
  NF.mapMenu = function (dc) { nmenu(dc, NF.MAP_MENU); };

  // ============================================================== NG: glance (C6)
  // Chrome (neighbouring glances, separators, launcher icon) is the watch's own: same layout as the OLD board.
  NG.chrome = function (dc) {
    dc.setColor(T.TEXT_1, T.BG); dc.clear();
    const c = dc.c;
    c.globalAlpha = .35; dc.setColor(T.RULE); dc.fillCircle(45, 40, 18); dc.fillCircle(45, 222, 18);
    dc.setColor(T.TEXT_2); dc.drawText(76, 30, "xtiny", "Body Battery", J.LEFT); dc.drawText(76, 212, "xtiny", "Weather", J.LEFT); c.globalAlpha = 1;
    dc.setColor(T.RULE); dc.drawLine(20, 84, 240, 84); dc.drawLine(20, 176, 240, 176);
    // launcher icon (the app's own bitmap resource, not part of the theme): the 1.1.0 steering wheel
    NG.appIcon(dc, 25, 110, 1);
  };
  // The 1.1.0 launcher icon (app/resources/drawables/launcher_icon.svg), drawn with Dc calls:
  // a three-spoke steering wheel, Electric Green rim and spokes, Emerald hub with a green edge,
  // transparent background. (x, y) is the top-left of the 40 x 40 icon; k scales it.
  NG.appIcon = function (dc, x, y, k) {
    const P = (px, py) => [x + px * k, y + py * k];
    dc.setColor(T.ACCENT); dc.setPenWidth(Math.max(1, Math.round(5 * k))); dc.drawCircle(x + 20 * k, y + 20 * k, 15.5 * k);
    dc.fillPolygon([P(6, 18.25), P(14.5, 17), P(14.5, 23), P(6, 21.75)]);
    dc.fillPolygon([P(34, 18.25), P(25.5, 17), P(25.5, 23), P(34, 21.75)]);
    dc.fillPolygon([P(17.75, 34), P(22.25, 34), P(23.25, 25.5), P(16.75, 25.5)]);
    dc.fillCircle(x + 20 * k, y + 20 * k, 6 * k);
    dc.setColor(T.EMERALD); dc.fillCircle(x + 20 * k, y + 20 * k, 3 * k);
    dc.setPenWidth(1);
  };
  // Content area 171 x 63 at (70, 99). Row 1 y 2, row 2 y 22, row 3 (SoC bar) y 55.
  NG.content = function (dc, o) {
    const X = 6, W = 171;
    if (!o.data) {
      dc.setColor(T.TEXT_2); dc.drawText(X, 2, "xtiny", "Vozidlo", J.LEFT);
      dc.drawText(X, 22, "tiny", Ui.fit(dc, "Open for your car", "tiny", W - X - 1), J.LEFT);
      return;
    }
    dc.setColor(T.TEXT_2); dc.drawText(X, 2, "xtiny", "Vozidlo", J.LEFT);
    dc.drawText(W - 6, 2, "xtiny", Age.short(NMOCK.ageMin), J.RIGHT);
    const soc = NMOCK.soc + "%", mid = 22 + Math.round(FM.tiny.h / 2);
    dc.setColor(T.TEXT_1); dc.drawText(X, 22, "tiny", soc, J.LEFT);
    let x = X + dc.getTextWidthInPixels(soc, "tiny") + 13;
    NIcons.draw(dc, "locked", x, mid, 8, T.TEXT_1); x += 11;
    dc.setColor(T.TEXT_1); dc.drawText(x, 22, "tiny", Labels.lock(NMOCK.lock), J.LEFT);
    x += dc.getTextWidthInPixels(Labels.lock(NMOCK.lock), "tiny") + 12;
    NIcons.draw(dc, "pluggedIn", x, mid, 8, T.TEXT_1);
    // 4 px SoC bar
    const bw = W - X - 6, fw = Math.round(bw * NMOCK.soc / 100);
    if (fw < bw) { dc.setColor(T.RULE); dc.fillRectangle(X + fw, 55, bw - fw, 4); }
    dc.setColor(T.TEXT_1); dc.fillRectangle(X, 55, fw, 4);
  };
  NG.glance = function (dc, o = {}) {
    NG.chrome(dc);
    dc.translate(70, 99); dc.setClip(0, 0, 171, 63);
    NG.content(dc, o);
    dc.clearClip(); dc.translate(-70, -99);
  };

  // ============================================================== NSet: settings
  NSet.ORDER = [{ label: "Climate", sub: "Position 1", icon: "fan" }, { label: "Charging", sub: "Position 2", icon: "bolt" },
    { label: "Find my car", sub: "Position 3", icon: "pin" }, { label: "Status", sub: "Position 4", icon: "list" }];
  NSet.ORDER_MOVED = [{ label: "Charging", sub: "Position 1", icon: "bolt" }, { label: "Climate", sub: "Position 2", icon: "fan" },
    { label: "Find my car", sub: "Position 3", icon: "pin" }, { label: "Status", sub: "Position 4", icon: "list" }];
  NSet.order = (dc, focus = 0) => nmenu(dc, { title: "Tile order", items: NSet.ORDER, focus });
  NSet.orderMoved = dc => nmenu(dc, { title: "Tile order", items: NSet.ORDER_MOVED, focus: 1 });
  NSet.item = (dc, focus = 1) => nmenu(dc, { title: "Climate", items: [{ label: "Move up" }, { label: "Move down" }, { label: "Hide" }], focus });
  NSet.temp = function (dc, v = NMOCK.targetTemp) {
    blank(dc);
    Ui.title(dc, "Target temperature", 48);       // 182 px: needs the chord at y 48, not 34
    Ui.drawValueWithUnit(dc, 130, 130 - Math.floor(FM.numMed.h / 2), String(v), "°C");
    Ui.drawBezelGlyph(dc, "up", "plus", T.TEXT_1);
    Ui.drawBezelGlyph(dc, "down", "minus", T.TEXT_1);
  };

  // ============================================================== NO: onboarding (C7)
  const GUIDE = "A key is created in the MyŠkoda app (v8.16+), not here. It only works for the vehicles you selected when you created it. Enter it in this app's phone settings.";
  NO.TEXT = {
    guide: GUIDE,
    check: "Checking your key against your car…",
    expiry: "Your key is probably close to expiring: this is an estimate, not a fact. If you would rather not be caught out, create a new one soon in the MyŠkoda app.",
    expired: "Your API key has expired. " + GUIDE
  };
  // Wrap on chord widths (extra margin keeps the lines clear of the bezel glyphs), small when <= 4 lines, else xtiny.
  NO.layout = function (dc, text, margin) {
    for (const f of ["small", "xtiny"]) {
      const lh = FM[f].h; let lines = [], count = 1;
      for (let pass = 0; pass < 8; pass++) {
        const top = 130 - Math.floor(count * lh / 2), widths = [];
        for (let i = 0; i < count; i++) widths.push(Ui.usable(top + i * lh, top + (i + 1) * lh, margin));
        lines = TB.wrap(text, widths, s => dc.getTextWidthInPixels(s, f));
        if (lines.length <= count) break; count = lines.length;
      }
      if (f === "small" && lines.length > 4) continue;
      return { f, lines, lh };
    }
  };
  NO.text = function (dc, text, o = {}) {
    blank(dc);
    const margin = o.glyphs ? 26 : 12;
    const { f, lines, lh } = NO.layout(dc, text, margin), top = 130 - Math.floor(lines.length * lh / 2);
    dc.setColor(T.TEXT_1); lines.forEach((l, i) => dc.drawText(130, top + i * lh, f, l, J.CENTER));
    if (o.menu) Ui.drawBezelGlyph(dc, "up", "menu", T.TEXT_1);              // hold UP = MENU: Onboarding menu
    if (o.ok) Ui.drawBezelGlyph(dc, "start", "check", T.ACCENT, "accent");  // START = continue
    return { f, lines: lines.length };
  };
  NO.menu = (dc, focus = 0) => nmenu(dc, { title: "Onboarding", items: [{ label: "Get a key" }, { label: "Clear stored data" }], focus });

  // ============================================================== NGUI: Garmin UI gallery
  const DEMO_ITEMS = [{ label: "Refresh", icon: "refresh" }, { label: "Charge limit", sub: "80%", icon: "bolt" }, { label: "Profiles", icon: "list" }];
  NGUI.under = dc => { blank(dc); Ui.title(dc, "Status"); Ui.drawValueWithUnit(dc, 130, 93, "100", "%"); };
  NGUI.underLow = dc => { blank(dc); Ui.drawValueWithUnit(dc, 130, 132, "100", "%"); };   // below the toast's rule at y 124
  NGUI.hints = function (dc) {
    blank(dc);
    Ui.drawHintArc(dc, "up", "dark"); Ui.drawHintArc(dc, "start", "accent"); Ui.drawHintArc(dc, "back", "positive"); Ui.drawHintArc(dc, "down", "destructive");
    dc.setColor(T.TEXT_2);
    dc.drawText(40, 130, "xtiny", "dark", J.LEFT | J.VCENTER);
    dc.drawText(196, 76, "xtiny", "accent", J.RIGHT | J.VCENTER);
    dc.drawText(196, 184, "xtiny", "positive", J.RIGHT | J.VCENTER);
    dc.drawText(62, 184, "xtiny", "destructive", J.LEFT | J.VCENTER);
  };

  // ============================================================== cards
  const NAV_KEYS = { START: "Map", MENU: "Navigate / Refresh (ActionMenu)", BACK: "Home" };
  CARDS.push(
    { id: "glance-data", section: "entry", name: "Glance, with cached data",
      neu: [{ label: "", draw: dc => NG.glance(dc, { data: true }), keys: { START: "Open app", "UP/DOWN": "Next glance" }, fitcheck: true }],
      fixes: ["A16", "A17", "C6"],
      changed: ["Three rows instead of one cut-off line: name and age, SoC + lock + plug, SoC bar.", "\"READY_FOR_CHARGING\" becomes a plug icon; \"LOCKED\" becomes \"Locked\".", "Age \"12 min\" now fits, right-aligned on row 1.", "\"Vozidlo\" grey, values white."],
      notes: ["Chrome (neighbouring glances, separators, launcher icon) is the watch's own, same as OLD; only the 171 × 63 content area is ours.", "Climate icon joins the plug when climate is on (off in the mock).", "Bar fill white; accent only while charging, like the rings."] },
    { id: "glance-empty", section: "entry", name: "Glance, nothing cached",
      neu: [{ label: "", draw: dc => NG.glance(dc, { data: false }), keys: { START: "Open app" }, fitcheck: true }],
      fixes: ["C6"], changed: ["\"Vozidlo\" on row 1, \"Open for your car\" in tiny grey on row 2."], notes: [] },

    { id: "fc-parked", section: "findcar", name: "Parked (Example distance and bearing)",
      neu: [{ label: "Example, compass heading", draw: dc => NF.parked(dc), keys: NAV_KEYS, fitcheck: true },
        { label: "Example, no heading yet", draw: dc => NF.parked(dc, { heading: false }), keys: NAV_KEYS, fitcheck: true }],
      fixes: ["A5", "A8", "A3", "A17", "C5"],
      changed: ["No title: the screen opens from the Find my car tile.", "Bearing is an accent pointer on a ring track at the bezel, not a green arrow in the middle.", "Address wraps on two chord lines instead of a 40-character cut.", "\"240\" in the number font, \"m\" in medium grey.", "Hint line gone: accent arc at START (map)."],
      notes: ["Mock address; 240 m and 35° are example values.", "Outline pointer while the watch has no compass heading (LocationMath falls back to north-up)."] },
    { id: "fc-gps", section: "findcar", name: "Waiting for GPS",
      neu: [{ label: "", draw: dc => NF.gps(dc), keys: { MENU: "Navigate / Refresh" }, fitcheck: true }],
      fixes: ["A18", "C5"], changed: ["\"Acquiring GPS position...\" becomes \"Waiting for GPS\", one line, grey.", "No pointer until a fix arrives; ring track stays."], notes: [] },
    { id: "fc-moving", section: "findcar", name: "Car is moving",
      neu: [{ label: "", draw: dc => NF.moving(dc), keys: { MENU: "Refresh" }, fitcheck: true }],
      fixes: ["A5", "A18", "C5"],
      changed: ["\"Car is moving\" as a hero word in medium white (was small yellow).", "\"Last parked\" without colon; address wraps on two lines."],
      notes: ["C5 says small at y 92; medium fits (167 px) and follows the hero rule (B4). Small is the fallback."] },
    { id: "fc-menu", section: "findcar", name: "Find my car menu",
      neu: [{ label: "ActionMenu", draw: dc => NF.menu(dc, 0), keys: { START: "Run", "UP/DOWN": "Move", BACK: "Close" }, fitcheck: true }],
      fixes: ["B6"], changed: ["Native ActionMenu over the screen instead of a full Menu2 with a title.", "\"Navigate to car\" shortens to \"Navigate\" (the context is on screen)."],
      notes: ["Full-screen list: nothing behind it gets cut off."] },
    { id: "fc-nav", section: "findcar", name: "Navigate confirmation",
      neu: [{ label: "", draw: dc => NF.nav(dc), keys: { START: "Yes: save waypoint, exit to navigation", DOWN: "No" }, fitcheck: true }],
      fixes: ["A18"], changed: ["Text cut to \"Navigate to the car? This closes the app.\" (2 sentences, no dash)."],
      notes: ["The system still asks again in exitTo; known Garmin bug: activity may start without the route."] },
    { id: "fc-map", section: "findcar", name: "Map preview",
      neu: [{ label: "Preview", draw: dc => NF.map(dc), keys: { START: "Browse (pan / zoom)", MENU: "Navigate to car", BACK: "Back" }, fitcheck: false },
        { label: "Browse mode", draw: dc => NF.map(dc, { browse: true }), keys: { BACK: "Back to preview" }, fitcheck: false }],
      fixes: ["B6"], changed: ["Unchanged map; a MENU handler is added (next card)."],
      notes: ["Tiles, pins and browse controls are Garmin's MapView; only the labels Car and You are ours.", { flag: "fitcheck off for this card: the map tile colours trip the monochrome check." }, "Park stand-in colour 0xAAFF55 (0xAAFFAA is banned)."] },
    { id: "fc-map-menu", section: "findcar", order: 406, name: "Map, MENU",
      neu: [{ label: "", draw: dc => NF.mapMenu(dc), keys: { START: "Navigate (confirmation first)", BACK: "Map" }, fitcheck: true }],
      fixes: ["B6"], changed: ["New: hold UP on the map opens a one-item Menu2 \"Navigate to car\"; OLD had no MENU handler."],
      notes: ["Same confirmation as from the Find my car screen."] },

    { id: "set-order", section: "settings", name: "Tile order",
      neu: [{ label: "", draw: dc => NSet.order(dc), keys: { START: "Edit item", "UP/DOWN": "Move focus" }, fitcheck: true }],
      fixes: ["B6"], changed: ["IconMenuItem with the category icons.", "\"Status detail\" becomes \"Status\"."], notes: ["Hidden categories show \"Hidden\" as sub-label."] },
    { id: "set-order-item", section: "settings", name: "Tile order item",
      neu: [{ label: "", draw: dc => NSet.item(dc), keys: { START: "Apply, back to the list" }, fitcheck: true }],
      fixes: [], changed: ["Same Menu2; push SLIDE_LEFT, pop SLIDE_RIGHT."], notes: ["\"Hide\" reads \"Show\" for a hidden category."] },
    { id: "set-order-moved", section: "settings", order: 503, name: "Tile order, after Move down",
      neu: [{ label: "", draw: dc => NSet.orderMoved(dc), keys: { START: "Edit item" }, fitcheck: true }],
      fixes: ["A20"], changed: ["New: focus follows the moved item, so \"Climate\" is focused at Position 2 (setFocus)."],
      notes: ["OLD rebuilt the list with focus on row 1."] },
    { id: "set-temp", section: "settings", name: "Target temperature",
      neu: [{ label: "", draw: dc => NSet.temp(dc), keys: { UP: "+1, saved right away", DOWN: "−1", "Swipe up": "+1", BACK: "Done" }, fitcheck: true }],
      fixes: ["A8", "A19"],
      changed: ["Title \"Target temperature\" added.", "\"21\" in the number font, \"°C\" in medium grey.", "Hint line replaced by + at UP and − at DOWN."],
      notes: ["The title is 182 px in tiny, so it sits at y 48 where the chord allows it (y 34 gives 158 px)."] },

    { id: "ob-guide", section: "onboarding", name: "No key yet",
      neu: [{ label: "", draw: dc => NO.text(dc, NO.TEXT.guide, { menu: true, glyphs: true }), keys: { MENU: "Onboarding menu", START: "Open the key page on the phone" }, fitcheck: true }],
      fixes: ["A22", "C7"], changed: ["\"Menu for more.\" becomes a menu glyph at UP.", "Text in the larger font when it fits in 4 lines."],
      notes: ["START opens the key page in guidance mode (OnboardingDelegate.onSelect); OLD card said Retry, which is the validating mode only.", { flag: "START has no glyph here: is a hint for \"open key page\" wanted?" }] },
    { id: "ob-check", section: "onboarding", name: "Checking the key",
      neu: [{ label: "", draw: dc => NO.text(dc, NO.TEXT.check), keys: {}, fitcheck: true }],
      fixes: ["C7"], changed: ["Small font instead of xtiny (2 lines)."], notes: [] },
    { id: "ob-expiry", section: "onboarding", name: "Key near expiry",
      neu: [{ label: "", draw: dc => NO.text(dc, NO.TEXT.expiry, { ok: true, glyphs: true }), keys: { START: "Continue to home" }, fitcheck: true }],
      fixes: ["A22", "C7"], changed: ["\"Select to continue.\" becomes a check glyph with accent arc at START."], notes: [] },
    { id: "ob-expired", section: "onboarding", name: "Key expired",
      neu: [{ label: "", draw: dc => NO.text(dc, NO.TEXT.expired, { menu: true, glyphs: true }), keys: { MENU: "Onboarding menu" }, fitcheck: true }],
      fixes: ["A22", "C7"], changed: ["\"Menu for more.\" becomes a menu glyph at UP.", "Lines kept clear of the glyph (extra margin)."], notes: ["Longest onboarding text; stays in xtiny."] },
    { id: "ob-menu", section: "onboarding", name: "Onboarding menu",
      neu: [{ label: "", draw: dc => NO.menu(dc), keys: { START: "Open" }, fitcheck: true }],
      fixes: ["A20"], changed: ["Same Menu2; push SLIDE_LEFT."], notes: ["Clear stored data always asks for confirmation."] },

    // ---- Garmin UI gallery
    { id: "gui-menu2", section: "garmin", order: 700, name: "Menu2",
      neu: [{ label: "Title + first item", draw: dc => menu2(dc, { title: "Charging", items: DEMO_ITEMS, focus: 0 }), fitcheck: true },
        { label: "Focus in the middle", draw: dc => menu2(dc, { title: "Charging", items: DEMO_ITEMS, focus: 1 }), fitcheck: true }],
      fixes: [], changed: ["Title 78, focused row 87 (small + tiny sub), neighbours 55 (tiny grey), focus bar 3 × 57 at x 13."],
      notes: ["From the fēnix 7 Pro device files (simulator.json layouts.menu2).", { flag: "Menu2 themes (MENU_THEME_DARK and friends) are not supported on this watch: always white on black." }] },
    { id: "gui-menu2-items", section: "garmin", order: 701, name: "Menu2, toggle and check items",
      neu: [{ label: "ToggleMenuItem", draw: dc => menu2(dc, { title: "Climate", items: [{ label: "Windscreen", sub: "Heat on", toggle: true }, { label: "Rear window", toggle: false }], focus: 0 }), fitcheck: true },
        { label: "CheckboxMenuItem", draw: dc => menu2(dc, { title: "Charge mode", items: [{ label: "Manual", check: true }, { label: "Timer", check: false }, { label: "Preferred times", check: false }], focus: 0 }), fitcheck: true }],
      fixes: [], changed: ["Toggle and check draw in the device's green; that green is Garmin's, not ours."], notes: ["Example labels."] },
    { id: "gui-confirm", section: "garmin", order: 702, name: "Confirmation",
      neu: [{ label: "", draw: dc => Native.confirmation(dc, "Clear stored data?"), keys: { START: "Yes", DOWN: "No" }, fitcheck: true }],
      fixes: [], changed: ["Body box 52..208 in tiny; green check at START, red cross at DOWN (personality.mss)."], notes: [] },
    { id: "gui-toast", section: "garmin", order: 703, name: "Toast",
      neu: [{ label: "Success", draw: dc => Native.toast(dc, NGUI.underLow, { text: "Command sent", icon: "check" }), fitcheck: true },
        { label: "Warning", draw: dc => Native.toast(dc, NGUI.underLow, { text: "Quota low", icon: "bang" }), fitcheck: true }],
      fixes: [], changed: ["Partial banner from the top: icon at y 46, one line of small text."], notes: ["Example texts."] },
    { id: "gui-actionmenu", section: "garmin", order: 704, name: "ActionMenu",
      neu: [{ label: "", draw: dc => Native.actionMenu(dc, NGUI.under, { items: ["Refresh", "Charging", "Settings"], focus: 0 }), keys: { "UP/DOWN": "Move", START: "Run", BACK: "Close" }, fitcheck: false }],
      fixes: [], changed: ["Panel x 147..260 with a 2 px white edge; selected entry at y 132."], notes: ["simulator.json actionMenu. Example entries.", "Garmin's panel cuts through the screen behind it; the redesign uses a full-screen list instead (not fit-checked here on purpose)."] },
    { id: "gui-indicator", section: "garmin", order: 705, name: "ViewLoop page indicator",
      neu: [{ label: "Native arc", draw: dc => { NGUI.under(dc); Ui.drawPageIndicator(dc, 1, 5, "arc"); }, decision: "D7", fitcheck: true },
        { label: "Custom dots", draw: dc => { NGUI.under(dc); Ui.drawPageIndicator(dc, 1, 5, "dots"); }, decision: "D7", fitcheck: true }],
      fixes: [], changed: ["Native: 6° white segments at r 116..124 on the left, current hollow.", "Dots: accent current, RULE others; means owning the paging."], notes: ["Page 2 of 5."] },
    { id: "gui-hints", section: "garmin", order: 706, name: "Button hint arcs",
      neu: [{ label: "", draw: dc => NGUI.hints(dc), fitcheck: true }],
      fixes: [], changed: ["Personality hint arcs: 4 px band r 124..128, ±10° around the button."],
      notes: ["Shown at UP (dark), START (accent), BACK (positive), DOWN (destructive); the kind is a colour, not a fixed button."] }
  );

  // ============================================================== simulator views
  SIM_VIEWS["new:findCar"] = {
    newDesign: true,
    init(o) { return { sub: null, focus: 0 }; },
    draw(dc, st) { if (st.sub === "action") NF.menu(dc, st.focus); else NF.parked(dc); },
    key(k, st) {
      if (st.sub === "action") {
        const n = NF.MENU_ITEMS.length;
        if (k === "UP" || k === "SWIPE_DOWN") { st.focus = (st.focus + n - 1) % n; return null; }
        if (k === "DOWN" || k === "SWIPE_UP") { st.focus = (st.focus + 1) % n; return null; }
        if (k === "BACK") { st.sub = null; return null; }
        if (k === "START" || k === "TAP") {
          const item = NF.MENU_ITEMS[st.focus]; st.sub = null; st.focus = 0;
          if (item === "Navigate") {
            const toast = { text: "Opening navigation", icon: "check" };
            const then = () => ({ toast }); then.toast = toast;   // works whether the sim calls it or reads it
            return { confirm: { text: NF.NAV_TEXT, then } };
          }
          return { toast: { text: "Refreshing", icon: "refresh" } };
        }
        return null;
      }
      if (k === "START" || k === "TAP") return { push: "new:mapPreview", o: {} };
      if (k === "MENU") { st.sub = "action"; st.focus = 0; return null; }
      if (k === "BACK") return { pop: true };
      return null;
    }
  };
  SIM_VIEWS["new:mapPreview"] = {
    newDesign: true,
    init(o) { return { browse: false, menu: false }; },
    draw(dc, st) { if (st.menu) NF.mapMenu(dc); else NF.map(dc, { browse: st.browse }); },
    key(k, st) {
      if (st.menu) {
        if (k === "BACK") { st.menu = false; return null; }
        if (k === "START" || k === "TAP") {
          st.menu = false;
          const toast = { text: "Opening navigation", icon: "check" };
          const then = () => ({ toast }); then.toast = toast;
          return { confirm: { text: NF.NAV_TEXT, then } };
        }
        return null;
      }
      if (k === "MENU") { st.menu = true; return null; }
      if (k === "START" || k === "TAP") { st.browse = !st.browse; return null; }
      if (k === "BACK") { if (st.browse) { st.browse = false; return null; } return { pop: true }; }
      return null;
    }
  };

  Object.assign(window, { NF, NG, NSet, NO, NGUI });
})();

// Lead: readable names for the simulator caption, for views registered without a title.
(function () {
  const names = { "new:statusLoop": "Status", "new:chargingDetail": "Charging", "new:chargeLimit": "Charge limit", "new:chargingProfiles": "Charging profiles",
    "new:findCar": "Find my car", "new:mapPreview": "Map", "new:homeGrid": "Home (grid)", "new:homeList": "Home (list)",
    "old:home": "Home", "old:status": "Status", "old:charging": "Charging", "old:findCar": "Find my car" };
  for (const k in names) if (SIM_VIEWS[k] && !SIM_VIEWS[k].title) SIM_VIEWS[k].title = names[k];
})();

// Lead: menus in the NEW design are drawn by the app itself in Škoda green (Ui.menu / Ui.actionMenu).
(function () {
  const MENU = "Menu in Škoda green: title and focused row green, black text on the focused row. On the watch a CustomMenu (Garmin's Menu2 cannot be recoloured on the fēnix 7 Pro), so scrolling and focus stay native.";
  const ACTION = "Actions as a full-screen list in Škoda green instead of Garmin's ActionMenu panel, which cuts through the screen behind it and cannot be recoloured. On the watch a CustomMenu.";
  const menus = ["home-more", "ch-menu", "ch-mode", "ch-limit", "ch-limit-care", "fc-map-menu", "set-order", "set-order-item", "set-order-moved", "ob-menu"];
  const actions = ["st-actionmenu", "fc-menu"];
  for (const c of CARDS) {
    const line = menus.includes(c.id) ? MENU : actions.includes(c.id) ? ACTION : null;
    if (!line) continue;
    (c.changed = c.changed || []).unshift(line);
    if (!(c.fixes || []).includes("B6")) (c.fixes = c.fixes || []).push("B6");
  }
})();
