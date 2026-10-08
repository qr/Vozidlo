// ================================================================ OLD screens (code-faithful port of app/source/ui at 3c4d005)
// ---------------------------------------------------------------- views
function controls(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  const strip = o.strip || { soc: MOCK.soc + "%", charging: MOCK.chargingState, lockRaw: MOCK.lock, chargingRaw: MOCK.chargingState, climateRaw: MOCK.climate };
  dc.setColor(COL.WHITE);
  dc.drawText(130, 18, "xtiny", strip.soc + "  " + strip.charging + "  " + (strip.lockRaw == null ? DASH : lockLabel(strip.lockRaw)), J.CENTER);
  Icons.draw(dc, Icons.forLock(strip.lockRaw), 130, 38, 9, COL.WHITE);
  const ci = Icons.forCharging(strip.chargingRaw); if (ci) Icons.draw(dc, ci, 90, 38, 9, COL.WHITE);
  const cl = Icons.forClimate(strip.climateRaw); if (cl) Icons.draw(dc, cl, 170, 38, 9, COL.WHITE);
  const tiles = o.tiles, scroll = o.scroll || 0, total = Math.ceil(tiles.length / 2);
  tiles.forEach((label, i) => {
    const col = i % 2, row = Math.floor(i / 2), x = col ? 135 : 35, y = 52 + (row - scroll) * 52;
    const st = i === o.hi ? "hi" : "def";
    dc.setColor(st === "hi" ? COL.BLUE : COL.DK_GRAY); dc.fillRoundedRectangle(x, y, 90, 46, 8);
    if (st === "hi") { dc.setPenWidth(2); dc.setColor(COL.WHITE); dc.drawRoundedRectangle(x, y, 90, 46, 8); dc.setPenWidth(1); }
    dc.setColor(COL.WHITE); dc.drawText(x + 45, y + 23, "xtiny", label, J.CENTER | J.VCENTER);
  });
  dc.setColor(COL.LT_GRAY);
  if (scroll > 0) dc.fillPolygon([[124, 50], [136, 50], [130, 44]]);
  if (scroll + 3 < total) dc.fillPolygon([[124, 206], [136, 206], [130, 212]]);
  if (o.msg) { dc.setColor(o.msg.err ? COL.ORANGE : COL.GREEN); dc.drawText(130, 216, "xtiny", o.msg.text, J.CENTER); }
  TB.fitted(dc, "UP charging - DOWN status", "xtiny", COL.DK_GRAY, 240);
}
const TILES_MOCK = ["Start\nclimate", "Stop\nclimate", "Start\ncharging", "Stop\ncharging", "Find\nmy car", "Status", "Settings"];
const TILES_UNKNOWN = ["Start\nclimate", "Stop\nclimate", "Start\nventilation", "Stop\nventilation", "Start\ncharging", "Stop\ncharging", "More"];

function ageText(min) { if (min < 1) return "Updated just now"; if (min < 60) return min + " min ago"; const h = Math.floor(min / 60); if (h < 24) return h + "h " + (min - h * 60) + "m ago"; return Math.floor(h / 24) + "d ago"; }

function statusPage(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  dc.setColor(COL.DK_GRAY); dc.drawText(130, 12, "xtiny", o.page + "/5", J.CENTER);
  dc.setColor(COL.LT_GRAY); dc.drawText(130, 28, "xtiny", "SELECT to refresh", J.CENTER);
  dc.setColor(COL.LT_GRAY); dc.drawText(130, 56, "small", o.title, J.CENTER);
  if (o.kind) {
    dc.setColor(COL.WHITE); dc.drawText(130, 100, "numMed", DASH, J.CENTER);
    dc.setColor(o.kind === "DISABLED" ? COL.LT_GRAY : COL.YELLOW); dc.drawText(130, 150, "small", o.kindLabel, J.CENTER);
  } else {
    const vc = o.emph ? COL.ORANGE : COL.WHITE;
    dc.setColor(vc); dc.drawText(130, 100, "numMed", o.value, J.CENTER);
    if (o.icon) { const vw = dc.getTextWidthInPixels(o.value, "numMed"); const ix = Math.min(130 + Math.floor(vw / 2) + 20, 242); Icons.draw(dc, o.icon, ix, 100 + 37, 12, vc); }
    dc.setColor(COL.WHITE); let y = 152;
    o.sub.slice(0, 3).forEach(s => { dc.drawText(130, y, "xtiny", s, J.CENTER); y += 16; });
    const stale = o.age > 60;
    dc.setColor(stale ? COL.RED : COL.DK_GRAY); dc.drawText(130, 210, stale ? "tiny" : "xtiny", (stale ? "! " : "") + ageText(o.age), J.CENTER);
  }
  dc.setColor(COL.DK_GRAY); dc.drawText(130, 260 - 22, "xtiny", "UP/DOWN pages - SELECT refresh", J.CENTER);
}

function chargingDetail(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  dc.setColor(COL.DK_GRAY); dc.drawText(130, 12, "xtiny", "CHARGING", J.CENTER);
  dc.setColor(COL.WHITE); dc.drawText(130, 60, "medium", o.state, J.CENTER);
  if (o.cable) { dc.setColor(COL.ORANGE); dc.drawText(130, 84, "xtiny", "No cable appears to be connected", J.CENTER); }
  dc.setColor(COL.WHITE); let y = 110;
  ["Type: " + o.type, "Power: " + o.power, "Rate: " + o.rate, "Remaining: " + o.remaining, "Full by: " + o.full].forEach(s => { dc.drawText(130, y, "xtiny", s, J.CENTER); y += 18; });
  if (o.msg) { dc.setColor(o.msg.err ? COL.ORANGE : COL.GREEN); dc.drawText(130, 196, "xtiny", o.msg.text, J.CENTER); }
  dc.setColor(COL.DK_GRAY); dc.drawText(130, 214, "xtiny", ageText(o.age), J.CENTER);
  dc.drawText(130, 240, "xtiny", "SELECT refresh - MENU actions", J.CENTER);
}

function chargeLimit(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  dc.setColor(COL.WHITE); dc.drawText(130, 110, "numMed", o.value + "%", J.CENTER);
  dc.setColor(COL.LT_GRAY); dc.drawText(130, 50, "small", "Charge limit", J.CENTER);
  if (o.recommended) { dc.setColor(COL.GREEN); dc.drawText(130, 150, "xtiny", "Recommended (battery care)", J.CENTER); }
  TB.fitted(dc, "UP/DOWN adjust - SELECT set", "xtiny", COL.DK_GRAY, 236);
}

function profiles(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  dc.setColor(COL.LT_GRAY); dc.drawText(130, 12, "xtiny", "CHARGING PROFILES", J.CENTER);
  if (o.unsupported) { dc.drawText(130, 120, "small", "Not supported\nby this car", J.CENTER); return; }
  const p = o.p;
  dc.setColor(p.current ? COL.GREEN : COL.WHITE); dc.drawText(130, 50, "small", p.current ? p.name + " (here)" : p.name, J.CENTER);
  dc.setColor(COL.WHITE); let y = 80;
  dc.drawText(130, y, "xtiny", "Target: " + p.target + "%", J.CENTER); y += 18;
  dc.drawText(130, y, "xtiny", "Max current: " + p.maxCurrent, J.CENTER); y += 18;
  dc.setColor(COL.LT_GRAY); p.timers.forEach(t => { dc.drawText(130, y, "xtiny", t, J.CENTER); y += 16; });
  TB.fitted(dc, o.idx + "/" + o.count + " - UP/DOWN", "xtiny", COL.DK_GRAY, 240);
}

function findCar(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  dc.setColor(COL.LT_GRAY); dc.drawText(130, 12, "small", "FIND MY CAR", J.CENTER);
  const addr = MOCK.address.length > 40 ? MOCK.address.slice(0, 40) : MOCK.address;
  if (o.mode === "moving") {
    dc.setColor(COL.YELLOW); dc.drawText(130, 110, "small", "Car is moving", J.CENTER);
    dc.setColor(COL.LT_GRAY); dc.drawText(130, 150, "xtiny", "Last parked:", J.CENTER); dc.drawText(130, 168, "xtiny", addr, J.CENTER);
    dc.setColor(COL.DK_GRAY); dc.drawText(130, 210, "xtiny", ageText(o.age), J.CENTER);
  } else {
    dc.setColor(COL.WHITE); dc.drawText(130, 56, "xtiny", addr, J.CENTER);
    if (o.mode === "gps") { dc.setColor(COL.LT_GRAY); dc.drawText(130, 120, "small", "Acquiring GPS\nposition...", J.CENTER); }
    else {
      dc.setColor(COL.WHITE); dc.drawText(130, 108, "numMed", o.distance, J.CENTER);
      const a = o.angle * Math.PI / 180, cx = 130, cy = 172, r = 28, br = r * 0.45, sp = 2.5;
      dc.setColor(COL.DK_GRAY); dc.drawCircle(cx, cy, r + 4);
      dc.setColor(COL.GREEN); dc.fillPolygon([[Math.trunc(cx + r * Math.sin(a)), Math.trunc(cy - r * Math.cos(a))], [Math.trunc(cx + br * Math.sin(a + sp)), Math.trunc(cy - br * Math.cos(a + sp))], [cx, cy], [Math.trunc(cx + br * Math.sin(a - sp)), Math.trunc(cy - br * Math.cos(a - sp))]]);
    }
    dc.setColor(COL.DK_GRAY); dc.drawText(130, 210, "xtiny", ageText(o.age), J.CENTER);
  }
  dc.setColor(COL.DK_GRAY); dc.drawText(130, 240, "xtiny", o.mode === "parked" ? "SELECT map - MENU navigate" : "MENU for options", J.CENTER);
}

function targetTemp(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  dc.setColor(COL.WHITE); dc.drawText(130, 130, "numMed", o.value + "°C", J.CENTER | J.VCENTER);
  TB.fitted(dc, "UP/DOWN to adjust", "xtiny", COL.DK_GRAY, 230);
}

function textScreen(dc, text) { dc.setColor(COL.WHITE, COL.BLACK); dc.clear(); TB.draw(dc, text, "xtiny", COL.WHITE); }

// --- Garmin system UI, approximated
// Garmin system UI: now drawn from the fēnix 7 Pro device files (Native), for OLD and NEW alike.
function menu2(dc, title, items, focus = 0) { Native.menu2(dc, { title, items, focus }); }
function confirmation(dc, text) { Native.confirmation(dc, text); }
function toastOver(dc, under, text) { Native.toast(dc, under, { text, icon: "check" }); }
function mapPreview(dc) {
  const c = dc.c; c.fillStyle = "#FFFFAA"; c.fillRect(0, 0, 260, 260);
  c.fillStyle = "#AAFFAA"; c.beginPath(); c.moveTo(20, 30); c.lineTo(110, 18); c.lineTo(120, 92); c.lineTo(36, 110); c.closePath(); c.fill();
  c.fillStyle = "#AAFFFF"; c.beginPath(); c.ellipse(205, 210, 60, 26, -0.4, 0, Math.PI * 2); c.fill();
  c.strokeStyle = "#FFFFFF"; c.lineWidth = 9; c.beginPath(); c.moveTo(-10, 150); c.lineTo(270, 120); c.moveTo(150, -10); c.lineTo(170, 270); c.stroke();
  c.strokeStyle = "#AAAAAA"; c.lineWidth = 1; c.beginPath(); c.moveTo(-10, 150); c.lineTo(270, 120); c.moveTo(150, -10); c.lineTo(170, 270); c.stroke();
  c.strokeStyle = "#FFFFFF"; c.lineWidth = 4; c.beginPath(); c.moveTo(60, 270); c.lineTo(120, 140); c.moveTo(165, 60); c.lineTo(260, 70); c.stroke();
  const pin = (x, y, label) => { dc.setColor(COL.RED); dc.fillCircle(x, y - 14, 8); dc.fillPolygon([[x - 6, y - 10], [x + 6, y - 10], [x, y]]); dc.setColor(COL.WHITE); dc.fillCircle(x, y - 14, 3); dc.setColor(COL.BLACK); dc.drawText(x, y + 2, "xtiny", label, J.CENTER); };
  pin(130, 136, "Car"); pin(96, 196, "You");
}
function glance(dc, o) {
  dc.setColor(COL.WHITE, COL.BLACK); dc.clear();
  const c = dc.c;
  // neighbouring glances, dimmed
  c.globalAlpha = .35; dc.setColor(COL.DK_GRAY); dc.fillCircle(45, 40, 18); dc.fillCircle(45, 222, 18);
  dc.setColor(COL.LT_GRAY); dc.drawText(76, 30, "xtiny", "Body Battery", J.LEFT); dc.drawText(76, 212, "xtiny", "Weather", J.LEFT); c.globalAlpha = 1;
  dc.setColor(COL.DK_GRAY); dc.drawLine(20, 84, 240, 84); dc.drawLine(20, 176, 240, 176);
  // launcher icon in the icon area
  const ix = 25, iy = 110;
  dc.setColor("#2B2F36"); dc.fillRoundedRectangle(ix, iy, 40, 40, 8);
  dc.setColor("#C7CDD6"); dc.fillPolygon([[5, 31], [5, 25], [9, 25], [14, 16], [26, 16], [31, 25], [35, 25], [35, 31]].map(([x, y]) => [ix + x, iy + y]));
  dc.setColor("#2B2F36"); dc.fillCircle(ix + 12.5, iy + 31.5, 4.5); dc.fillCircle(ix + 27.5, iy + 31.5, 4.5);
  dc.setColor("#C7CDD6"); dc.setPenWidth(3); dc.drawCircle(ix + 29, iy + 10, 6.5); dc.setColor("#2B2F36"); dc.fillRectangle(ix + 27.5, iy + 1.5, 3, 5.5);
  dc.setColor("#C7CDD6"); dc.drawLine(ix + 29, iy + 3, ix + 29, iy + 10); dc.setPenWidth(1);
  // content area 171 x 63 at x 70, centred on the row
  c.save(); c.translate(70, 99); c.beginPath(); c.rect(0, 0, 171, 63); c.clip();
  const midY = 31;
  dc.setColor(COL.WHITE); dc.drawText(8, midY - 10, "xtiny", "Vozidlo", J.LEFT | J.VCENTER);
  const measure = s => dc.getTextWidthInPixels(s, "xtiny");
  const trunc = (t, mw) => { if (measure(t) <= mw) return t; let s = t; while (s.length > 1 && measure(s + "…") > mw) s = s.slice(0, -1); return s + "…"; };
  if (o.data) {
    Icons.draw(dc, "locked", 8, midY + 10, 7, COL.WHITE);
    dc.setColor(COL.WHITE); dc.drawText(18, midY + 10, "xtiny", trunc("100%  READY_FOR_CHARGING  LOCKED  12 min ago", 171 - 18 - 4), J.LEFT | J.VCENTER);
  } else { dc.setColor(COL.LT_GRAY); dc.drawText(8, midY + 10, "xtiny", trunc("Open for your car", 171 - 12), J.LEFT | J.VCENTER); }
  c.restore();
}

const GUIDE = "Open for your car";
const OB_GUIDANCE = "A key is created in the MyŠkoda app (v8.16+), not here. It only works for the vehicles you selected when you created it. Enter it in this app's phone settings. Menu for more.";
const KEYS = (o) => Object.entries(o);

const SECTIONS = [
 { id: "entry", title: "Entry", src: "ui/GlanceView.mc", blurb: "The glance in the widget loop. It only reads the cache and never makes a request. START opens the app on the home tiles.", screens: [
  { id: "glance-data", name: "Glance, with cached data", tags: ["mock", "sys"], src: "ui/GlanceView.mc · onUpdate", draw: dc => glance(dc, { data: true }),
    keys: { START: "Open app (home)", "UP/DOWN": "Next glance" },
    notes: ["Neighbouring glances and separators are the watch's own; only the 171 × 63 content area is ours.", { flag: "The summary repeats the raw enum READY_FOR_CHARGING and is cut off with …; the age never fits." }, "Lock icon sits on the second line's centre, left of the text."] },
  { id: "glance-empty", name: "Glance, nothing cached", tags: ["sys"], src: "ui/GlanceView.mc · onUpdate", draw: dc => glance(dc, { data: false }),
    keys: { START: "Open app" }, notes: ["Shown before the first successful request."] },
 ]},
 { id: "home", title: "Home: control tiles", src: "ui/ControlsView.mc", blurb: "The app lands here (US-036). Status strip on top, a 2-column grid of 90 × 46 tiles with 3 rows visible, a status line and a fitted hint at the bottom.", screens: [
  { id: "home-mock", name: "Home", tags: ["mock"], src: "ui/ControlsView.mc · onUpdate", draw: dc => controls(dc, { tiles: TILES_MOCK, hi: 0 }),
    keys: { START: "Activate highlighted tile", UP: "Charging detail", DOWN: "Status pages", BACK: "Exit app", "Touch": "Tap = run tile (SDK; verify on watch)" },
    notes: ["Mock vehicle: climate + charging operations only, so 7 tiles and no More.", { flag: "Strip text is about 250 px wide where the circle allows about 130 px." }, { flag: "Fitted hint lands at y ≈ 208, on the scroll arrow and the fourth row (Settings) that peeks out under row 3." }] },
  { id: "home-scrolled", name: "Home, scrolled to Settings", tags: ["mock"], src: "ui/ControlsView.mc · ensureTileVisible", draw: dc => controls(dc, { tiles: TILES_MOCK, hi: 6, scroll: 1 }),
    keys: { START: "Open Tile order" },
    notes: [{ flag: "Row 1 moves to y = 0 and covers the strip; the tiles are not clipped to the grid area." }] },
  { id: "home-unknown", name: "Home, first launch (no operations cached)", tags: [], src: "ui/ControlsView.mc · ControlTiles.capped", draw: dc => controls(dc, { tiles: TILES_UNKNOWN, hi: 0, strip: { soc: DASH, charging: DASH, lockRaw: null } }),
    keys: { START: "Activate tile" },
    notes: ["Unknown operations means every action is offered: 9 tiles, capped at 7 with More.", "Find my car, Status and Settings end up behind More.", "This is the layout in the current store screenshots."] },
  { id: "home-sent", name: "Home, after a command", tags: ["mock"], src: "ui/ControlsView.mc · _announceSent", draw: dc => controls(dc, { tiles: TILES_MOCK, hi: 0, msg: { text: "Command sent", err: false } }),
    keys: {}, notes: ["Status line at y = 216, green; orange for errors such as \"Not sent: …\" or \"Quota spent for this hour\".", "Same text also goes to a toast."] },
  { id: "home-toast", name: "Toast", tags: ["sys"], src: "WatchUi.showToast", draw: dc => toastOver(dc, d => controls(d, { tiles: TILES_MOCK, hi: 0 }), "Command sent"),
    keys: {}, notes: ["Garmin draws the toast; position and style are approximated.", "A 200 ms vibration goes with every sent command."] },
  { id: "home-confirm", name: "Confirmation", tags: ["sys"], src: "api/ConfirmationPolicy.mc", draw: dc => confirmation(dc, "Stop charging?"),
    keys: { START: "Yes, send", BACK: "No" },
    notes: ["Always asked for: stop charging, aux heater start/stop, clear data.", "Asked for everything else only when the quota estimate is low."] },
  { id: "home-more", name: "More menu", tags: ["sys"], src: "ui/ControlsView.mc · openMoreActions", draw: dc => menu2(dc, "More", [{ label: "Find\nmy car" }, { label: "Status" }, { label: "Settings" }]),
    keys: { START: "Open", BACK: "Back to tiles" },
    notes: [{ flag: "Reuses the tile label, so \"Find\\nmy car\" carries a line break into the menu." }] },
 ]},
 { id: "status", title: "Status pages", src: "ui/StatusView.mc", blurb: "DOWN from home. Five pages, one per API section, looped with UP/DOWN. Each page: counter, quota line, title, one big value, up to three sub-lines and that section's own age.", screens: [
  { id: "st-lock", name: "1 · Lock & doors", tags: ["mock"], src: "ui/StatusView.mc · _drawPage", draw: dc => statusPage(dc, { page: 1, title: "LOCK & DOORS", value: "LOCKED", icon: "locked", sub: ["Doors CLOSED", "Windows CLOSED", "Lights OFF"], age: 13 }),
    keys: { "UP/DOWN": "Previous / next page", START: "Refresh (1 request)", BACK: "Home" },
    notes: [{ flag: "LOCKED is drawn in the number font, which has no letters." }, "Bonnet and Trunk do not fit: only three sub-lines are shown.", { flag: "Bottom hint is clipped by the bezel." }] },
  { id: "st-fuel", name: "2 · Fuel / range", tags: ["mock"], src: "ui/StatusView.mc · _drawPage", draw: dc => statusPage(dc, { page: 2, title: "FUEL / RANGE", value: "436 km", sub: ["GASOLINE 62%", "ELECTRIC 100%"], age: 12 }),
    keys: { "UP/DOWN": "Pages" }, notes: [{ flag: "The km unit is outside the number font." }, "Engine types are shown as raw enums."] },
  { id: "st-charging", name: "3 · Charging", tags: ["mock"], src: "ui/StatusView.mc · _drawPage", draw: dc => statusPage(dc, { page: 3, title: "CHARGING", value: "100%", icon: "pluggedIn", sub: ["READY_FOR_CHARGING", "36 km range"], age: 12 }),
    keys: { "UP/DOWN": "Pages" }, notes: ["The one value that fits the number font as is."] },
  { id: "st-odo", name: "4 · Odometer", tags: ["mock"], src: "ui/StatusView.mc · _drawPage", draw: dc => statusPage(dc, { page: 4, title: "ODOMETER", value: "123456 km", sub: [], age: 12 }),
    keys: { "UP/DOWN": "Pages" }, notes: ["Digits plus unit nearly fill the circle at that height; a six-digit odometer is common."] },
  { id: "st-ac", name: "5 · Air conditioning", tags: ["mock"], src: "ui/StatusView.mc · _drawPage", draw: dc => statusPage(dc, { page: 5, title: "AIR CONDITIONING", value: "OFF", sub: ["Front window heat OFF", "Rear window heat OFF"], age: 12 }),
    keys: { "UP/DOWN": "Pages" }, notes: ["No icon when climate is off."] },
  { id: "st-ac-stale", name: "5 · Air conditioning, 17 h old", tags: ["mock"], src: "mock scenario stale-airconditioning-17h", draw: dc => statusPage(dc, { page: 5, title: "AIR CONDITIONING", value: "OFF", sub: ["Front window heat OFF", "Rear window heat OFF"], age: 17 * 60 }),
    keys: {}, notes: ["Older than an hour: age turns red, larger, with \"!\" (US-009)."] },
  { id: "st-nodata", name: "Section without data", tags: [], src: "ui/StatusView.mc · _kindLabel", draw: dc => statusPage(dc, { page: 5, title: "AIR CONDITIONING", kind: "UNKNOWN", kindLabel: "No data yet - refresh to fetch" }),
    keys: { START: "Refresh" }, notes: [{ flag: "Yellow label is about 255 px wide in the small font at y = 150." }, "Other states: Temporarily unavailable, Switched off for this car (grey)."] },
 ]},
 { id: "charging", title: "Charging", src: "ui/ChargingDetailView.mc", blurb: "UP from home. State, five detail lines, MENU for limit, mode and profiles.", screens: [
  { id: "ch-detail", name: "Charging detail", tags: ["mock"], src: "ui/ChargingDetailView.mc · onUpdate", draw: dc => chargingDetail(dc, { state: "Ready to charge", type: "Not charging", power: DASH, rate: DASH, remaining: DASH, full: DASH, age: 12 }),
    keys: { START: "Refresh", MENU: "Charging menu (hold UP)", BACK: "Home" },
    notes: ["Mock car is plugged in but not charging.", { flag: "Bottom hint is clipped by the bezel." }] },
  { id: "ch-active", name: "Charging detail, while charging", tags: ["ex"], src: "ui/ChargingDetailView.mc · onUpdate", draw: dc => chargingDetail(dc, { state: "Charging", type: "AC", power: "7.2 kW", rate: "38.0 km/h", remaining: "95 min", full: "18:40", age: 3 }),
    keys: {}, notes: ["Example values, not from the mock."] },
  { id: "ch-cable", name: "Cable warning", tags: ["ex"], src: "ChargingLogic.needsCableWarning", draw: dc => chargingDetail(dc, { state: "Connect the cable", cable: true, type: "Not charging", power: DASH, rate: DASH, remaining: DASH, full: DASH, age: 5 }),
    keys: {}, notes: ["The orange warning line fits the circle at y = 84 (measured)."] },
  { id: "ch-menu", name: "Charging menu", tags: ["sys", "mock"], src: "ui/ChargingDetailView.mc · openMenu", draw: dc => menu2(dc, "Charging", [{ label: "Refresh" }, { label: "Set charge limit" }, { label: "Charging profiles" }]),
    keys: { START: "Open", BACK: "Charging detail" }, notes: ["Set charge mode is hidden: the mock reports no available modes."] },
  { id: "ch-limit", name: "Charge limit", tags: ["mock"], src: "ui/ChargingLimitView.mc · onUpdate", draw: dc => chargeLimit(dc, { value: 80 }),
    keys: { "UP/DOWN": "50 · 60 · 70 · 80 · 90 · 100", START: "Set (asks when quota is low)" }, notes: ["Starts at 80% when the car reports no limit."] },
  { id: "ch-limit-care", name: "Charge limit, battery-care match", tags: ["ex"], src: "ui/ChargingLimitView.mc · onUpdate", draw: dc => chargeLimit(dc, { value: 80, recommended: true }),
    keys: {}, notes: ["Green line when the value equals the car's battery-care target."] },
  { id: "ch-mode", name: "Charge mode", tags: ["sys", "ex"], src: "ui/ChargingModeView.mc", draw: dc => menu2(dc, "Charge mode", [{ label: "Manual", sub: "Current" }, { label: "Timer" }, { label: "Preferred times" }]),
    keys: { START: "Set mode" }, notes: ["Example modes; only shown when the car lists any."] },
  { id: "ch-profiles", name: "Charging profiles", tags: ["mock"], src: "ui/ChargingProfilesView.mc · onUpdate", draw: dc => profiles(dc, { unsupported: true }),
    keys: { "UP/DOWN": "Profiles", START: "Load" }, notes: ["The mock car has no profiles."] },
  { id: "ch-profile-ex", name: "Charging profile page", tags: ["ex"], src: "ui/ChargingProfilesView.mc · _drawProfile", draw: dc => profiles(dc, { idx: 1, count: 2, p: { name: "Home", current: true, target: 80, maxCurrent: "Reduced", timers: ["22:00 Mon,Tue,Wed,Thu,Fri", "07:30 Sat,Sun"] } }),
    keys: { "UP/DOWN": "Next profile" }, notes: ["Example profile. Green name means the car is at this profile's location."] },
 ]},
 { id: "findcar", title: "Find my car", src: "ui/LocationView.mc", blurb: "From the Find my car tile. Distance and a bearing arrow that follows the watch heading; START for the map, MENU to navigate.", screens: [
  { id: "fc-parked", name: "Parked", tags: ["mock", "ex"], src: "ui/LocationView.mc · _drawParked", draw: dc => findCar(dc, { mode: "parked", distance: "240 m", angle: 35, age: 12 }),
    keys: { START: "Map", MENU: "Navigate / Refresh", BACK: "Home" },
    notes: ["Mock address; distance and bearing are example values.", { flag: "The m unit is outside the number font." }, "Address is cut at 40 characters, not at a word."] },
  { id: "fc-gps", name: "Waiting for GPS", tags: ["mock"], src: "ui/LocationView.mc · _drawParked", draw: dc => findCar(dc, { mode: "gps", age: 12 }),
    keys: { MENU: "Options" }, notes: [] },
  { id: "fc-moving", name: "Car is moving", tags: ["mock"], src: "ui/LocationView.mc · onUpdate", draw: dc => findCar(dc, { mode: "moving", age: 12 }),
    keys: { MENU: "Options" }, notes: ["Shows the last parked address from storage."] },
  { id: "fc-menu", name: "Find my car menu", tags: ["sys"], src: "LocationActionMenu.push", draw: dc => menu2(dc, "Find my car", [{ label: "Navigate to car" }, { label: "Refresh" }]),
    keys: { START: "Open" }, notes: [] },
  { id: "fc-nav", name: "Navigate confirmation", tags: ["sys"], src: "ui/LocationView.mc · confirmNavigate", draw: dc => confirmation(dc, "Navigate to the car? This closes this app - starting navigation always exits to the system."),
    keys: { START: "Save waypoint, exit to navigation" }, notes: ["The system then asks again (exitTo). Known Garmin bug: activity may start without the route."] },
  { id: "fc-map", name: "Map preview", tags: ["sys"], src: "ui/MapPreviewView.mc", draw: dc => mapPreview(dc),
    keys: { START: "Browse mode (pan / zoom)", BACK: "Back (browse, then preview, then out)" },
    notes: ["Native MapView, 400 m around the car; drawn here as a stand-in.", { flag: "No MENU handler, so no way to navigate from the map." }] },
 ]},
 { id: "settings", title: "Settings", src: "ui/TileOrderView.mc", blurb: "Tile order from the Settings tile; target temperature from Garmin's app-settings entry.", screens: [
  { id: "set-order", name: "Tile order", tags: ["sys"], src: "ui/TileOrderView.mc", draw: dc => menu2(dc, "Tile order", [{ label: "Climate", sub: "Position 1" }, { label: "Charging", sub: "Position 2" }, { label: "Find my car", sub: "Position 3" }, { label: "Status detail", sub: "Position 4" }], 0),
    keys: { START: "Edit item" }, notes: ["Hidden categories show \"Hidden\" as sub-label."] },
  { id: "set-order-item", name: "Tile order item", tags: ["sys"], src: "ui/TileOrderView.mc · TileOrderDetailMenu", draw: dc => menu2(dc, "Climate", [{ label: "Move up" }, { label: "Move down" }, { label: "Hide" }], 1),
    keys: { START: "Apply" }, notes: [] },
  { id: "set-temp", name: "Target temperature", tags: ["mock"], src: "ui/TargetTemperatureSettingsView.mc", draw: dc => targetTemp(dc, { value: 21 }),
    keys: { "UP/DOWN": "± 1 degree, saved right away" }, notes: [{ flag: "°C: the C is outside the number font." }, "No title on screen."] },
 ]},
 { id: "onboarding", title: "Onboarding", src: "ui/OnboardingGate.mc", blurb: "Before home, when the key or VIN is missing, never validated, near its estimated expiry, or rejected. All text screens use TextBlock: wrapped to the circle and centred.", screens: [
  { id: "ob-guide", name: "No key yet", tags: [], src: "ui/OnboardingView.mc", draw: dc => textScreen(dc, OB_GUIDANCE),
    keys: { MENU: "Onboarding menu", START: "Retry" }, notes: [] },
  { id: "ob-check", name: "Checking the key", tags: [], src: "ui/OnboardingView.mc", draw: dc => textScreen(dc, "Checking your key against your car…"), keys: {}, notes: [] },
  { id: "ob-expiry", name: "Key near expiry", tags: [], src: "ui/OnboardingExpiryNoticeView.mc", draw: dc => textScreen(dc, "Your key is probably close to expiring: this is an estimate, not a fact. If you would rather not be caught out, create a new one soon in the MyŠkoda app. Select to continue."),
    keys: { START: "Continue to home" }, notes: [] },
  { id: "ob-expired", name: "Key expired", tags: [], src: "ui/OnboardingGate.mc · _expiredText", draw: dc => textScreen(dc, "Your API key has expired. " + OB_GUIDANCE),
    keys: { MENU: "Onboarding menu" }, notes: [{ flag: "Long text: check whether the last lines are cut." }] },
  { id: "ob-menu", name: "Onboarding menu", tags: ["sys"], src: "ui/OnboardingActionMenu.mc", draw: dc => menu2(dc, "Onboarding", [{ label: "Get a key" }, { label: "Clear stored data" }]),
    keys: { START: "Open" }, notes: ["Clear stored data always asks for confirmation."] },
 ]},
];

const TAGS = { mock: ["mock", "Mock data"], ex: ["ex", "Example data"], sys: ["sys", "Garmin UI, approx."] };

// Device check (Bart, 2026-10-07): on the fēnix 7 Pro UP/DOWN on home move the tile focus.
(function fixOldHomeKeys() {
  const home = SECTIONS.find(s => s.id === "home");
  home.blurb = "The app lands here (US-036). Status strip on top, a 2-column grid of 90 × 46 tiles with 3 rows visible, a status line and a fitted hint at the bottom. On the watch UP/DOWN move the tile focus.";
  const m = home.screens.find(s => s.id === "home-mock");
  m.keys = { START: "Activate focused tile", "UP/DOWN": "Move tile focus (verified on the watch)", BACK: "Exit app", "Swipe down": "Charging detail (not confirmed)", "Swipe up": "Status pages", Touch: "Tap = run tile (SDK; verify on watch)" };
  m.notes.push({ flag: "The hint promises UP = charging and DOWN = status, but UP/DOWN move the focus. Charging detail, charge limit, mode and profiles cannot be reached with buttons." });
  for (const s of SECTIONS) for (const scr of s.screens) if (scr.tags.includes("sys")) scr.tags = scr.tags.map(t => t === "sys" ? "native" : t);
})();
TAGS.native = ["sys", "Garmin UI, from device files"];
const SECTION_META = {};
SECTIONS.forEach((s, si) => {
  SECTION_META[s.id] = { title: s.title, src: s.src, blurb: s.blurb };
  s.screens.forEach((scr, i) => { OLD_SCREENS[scr.id] = Object.assign({ section: s.id, order: si * 100 + i }, scr); });
});
SECTION_META.garmin = { title: "Garmin UI", src: "Toybox.WatchUi", blurb: "Native components drawn from the fēnix 7 Pro device files (simulator.json, personality.mss). Used by both OLD and NEW." };

