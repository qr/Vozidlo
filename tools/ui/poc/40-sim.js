// ================================================================ Interactive simulator (agent B)
// Two watches (OLD | NEW), a view stack per watch, bezel buttons, touch, keyboard and #sim= replay.
(function () {
  const SIM = {};
  const K = ["UP", "DOWN", "START", "BACK", "MENU", "SWIPE_UP", "SWIPE_DOWN", "TAP"];
  const nextKey = k => k === "DOWN" || k === "SWIPE_UP", prevKey = k => k === "UP" || k === "SWIPE_DOWN";
  const sent = () => ({ toast: { text: "Command sent", icon: "check" } });

  // Moves a NEW list's focus; a step of one row slides (Ui.slideShift), a wrap or no move jumps.
  // Ui.SLIDE_MS 0 (fitcheck) switches the slide off.
  const slideTo = (s, focus) => {
    const d = focus - s.focus;
    s.slide = Math.abs(d) === 1 && Ui.SLIDE_MS > 0 ? { d, t0: performance.now() } : null;
    s.focus = focus;
  };

  // ---------------------------------------------------------------- shared native views
  // Menu2: o = {title, items: [{label, sub, icon, result}], focus}. START runs item.result (default: pop).
  SIM_VIEWS["native:menu2"] = {
    newDesign: false, title: "Menu2",
    init(o = {}) { return { title: o.title || "", items: o.items || [], focus: o.focus || 0, style: o.style || "native" }; },
    draw(dc, s) {
      if (s.style === "new") Ui.menu(dc, { title: s.title, items: s.items, focus: s.focus, shift: Ui.slideShift(s.slide, performance.now()) });
      else Native.menu2(dc, { title: s.title, items: s.items, focus: s.focus });
    },
    key(k, s) {
      const n = s.items.length;
      if (nextKey(k)) { slideTo(s, Math.min(n - 1, s.focus + 1)); return null; }
      if (prevKey(k)) { slideTo(s, Math.max(0, s.focus - 1)); return null; }
      if (k === "START" || k === "TAP") { const it = s.items[s.focus]; return (it && it.result) || { pop: true }; }
      return undefined;
    }
  };

  // ---------------------------------------------------------------- OLD views (faithful to the app)
  const OLD_TILE_ORDER = [{ label: "Climate", sub: "Position 1" }, { label: "Charging", sub: "Position 2" }, { label: "Find my car", sub: "Position 3" }, { label: "Status detail", sub: "Position 4" }];
  const oldMenu = (title, items) => ({ push: "native:menu2", o: { title, items } });
  SIM_VIEWS["old:home"] = {
    title: "Home (tiles)",
    init() { return { focus: 0, scroll: 0, msg: null }; },
    draw(dc, s) { controls(dc, { tiles: TILES_MOCK, hi: s.focus, scroll: s.scroll, msg: s.msg }); },
    // ControlsView.onShow rebuilds the tiles: focus and scroll go back to the top; the message survives.
    resume(s) { s.focus = 0; s.scroll = 0; },
    key(k, s) {
      const n = TILES_MOCK.length, rows = Math.ceil(n / 2);
      if (k === "UP" || k === "DOWN") {
        s.focus = Math.max(0, Math.min(n - 1, s.focus + (k === "DOWN" ? 1 : -1)));
        s.scroll = NH.offsetFor(s.scroll, Math.floor(s.focus / 2), 3, rows); return null;
      }
      if (k === "SWIPE_DOWN") return { push: "old:charging" };
      if (k === "SWIPE_UP") return { push: "old:status" };
      if (k === "START" || k === "TAP") {
        const label = TILES_MOCK[s.focus].replace(/\n/g, " ");
        const fire = () => { s.msg = { text: "Command sent", err: false }; return sent(); };
        if (label === "Stop charging") return { confirm: { text: "Stop charging?", then: fire } };
        if (label === "Find my car") return { push: "old:findCar" };
        if (label === "Status") return { push: "old:status" };
        if (label === "Settings") return oldMenu("Tile order", OLD_TILE_ORDER);
        return fire();
      }
      return undefined;
    }
  };
  const OLD_PAGES = ["st-lock", "st-fuel", "st-charging", "st-odo", "st-ac"];
  SIM_VIEWS["old:status"] = {
    title: "Status pages",
    init() { return { page: 0 }; },
    draw(dc, s) { OLD_SCREENS[OLD_PAGES[s.page]].draw(dc); },
    key(k, s) {
      if (nextKey(k)) { s.page = (s.page + 1) % 5; return null; }
      if (prevKey(k)) { s.page = (s.page + 4) % 5; return null; }
      if (k === "START") return null;   // refresh: one request, page redraws with fresh data
      return undefined;
    }
  };
  SIM_VIEWS["old:charging"] = {
    title: "Charging detail",
    init() { return {}; },
    draw(dc) { OLD_SCREENS["ch-detail"].draw(dc); },
    key(k) {
      if (k === "MENU") return oldMenu("Charging", [{ label: "Refresh" }, { label: "Set charge limit", result: { replace: "old:chargeLimit" } }, { label: "Charging profiles", result: { replace: "old:profiles" } }]);
      if (k === "START") return null;   // refresh
      if (k === "UP" || k === "DOWN") return null;   // nothing on this view
      return undefined;
    }
  };
  SIM_VIEWS["old:chargeLimit"] = {
    title: "Charge limit",
    init() { return { value: 80 }; },
    draw(dc, s) { chargeLimit(dc, { value: s.value }); },
    key(k, s) {
      if (k === "UP" || k === "SWIPE_DOWN") { s.value = Math.min(100, s.value + 10); return null; }
      if (k === "DOWN" || k === "SWIPE_UP") { s.value = Math.max(50, s.value - 10); return null; }
      if (k === "START") return [{ pop: true }, { toast: { text: "Charge limit set", icon: "check" } }];
      return undefined;
    }
  };
  SIM_VIEWS["old:profiles"] = { title: "Charging profiles", init() { return {}; }, draw(dc) { OLD_SCREENS["ch-profiles"].draw(dc); }, key() { return undefined; } };
  SIM_VIEWS["old:findCar"] = {
    title: "Find my car",
    init() { return {}; },
    draw(dc) { findCar(dc, { mode: "parked", distance: "240 m", angle: 35, age: 12 }); },
    key(k) {
      if (k === "START") return { push: "old:map" };
      if (k === "MENU") return oldMenu("Find my car", [
        { label: "Navigate to car", result: [{ pop: true }, { confirm: { text: "Navigate to the car? This closes this app - starting navigation always exits to the system.", then: { toast: { text: "Exit to navigation", icon: "check" } } } }] },
        { label: "Refresh" }]);
      return undefined;
    }
  };
  SIM_VIEWS["old:map"] = { title: "Map preview", init() { return {}; }, draw(dc) { mapPreview(dc); }, key() { return undefined; } };

  // ---------------------------------------------------------------- NEW home views
  const NEW_TILE_ORDER = [{ label: "Climate", sub: "Position 1", icon: "climate" }, { label: "Charging", sub: "Position 2", icon: "bolt" }, { label: "Find my car", sub: "Position 3", icon: "pin" }, { label: "Status", sub: "Position 4", icon: "list" }];
  const opts = s => ({ variant: s.variant, d2: s.d2, d4: s.d4, d7: s.d7 });
  const openCharging = s => s.d2 === "merged" ? { push: "new:statusLoop", o: Object.assign(opts(s), { page: "charging" }) } : { push: "new:chargingDetail", o: opts(s) };
  const openStatus = s => ({ push: "new:statusLoop", o: Object.assign(opts(s), { page: "lock" }) });
  // Shared action dispatch for both NEW variants; focus is kept (A11, A12).
  function runNew(label, s) {
    const fire = () => { s.msg = { text: "Sent", kind: "sent" }; return sent(); };
    if (label === "Stop charging") return { confirm: { text: "Stop charging?", then: fire } };
    if (label === "Charging") return openCharging(s);
    if (label === "Status") return openStatus(s);
    if (label === "Find my car") return { push: "new:findCar", o: opts(s) };
    if (label === "Settings") return { push: "native:menu2", o: { title: "Tile order", items: NEW_TILE_ORDER, style: "new" } };
    if (label === "More") return { push: "native:menu2", o: { style: "new", title: "More", items: NH.moreItems(s.all || NH.TILES).map(l => ({ label: l, icon: NH.ICON[l], result: [{ pop: true }, runNew(l, s)] })) } };
    return fire();
  }
  const baseInit = (o = {}) => ({ variant: o.variant || "b", d2: o.d2 || "separate", d4: o.d4 || "refresh", d7: o.d7 || "arc", focus: 0, scroll: 0, msg: null });
  SIM_VIEWS["new:homeGrid"] = {
    newDesign: true, title: "Home (a) grid",
    init(o) { const s = baseInit(o); s.tiles = NH.capGrid(NH.TILES); return s; },
    draw(dc, s) { NH.grid(dc, { tiles: s.tiles, focus: s.focus, scroll: s.scroll, msg: s.msg }); },
    key(k, s) {
      const n = s.tiles.length, step = { UP: -1, DOWN: 1, SWIPE_UP: 2, SWIPE_DOWN: -2 }[k];
      if (step) {   // buttons move focus by one tile; a swipe scrolls one row and takes the focus along (A13)
        s.focus = Math.max(0, Math.min(n - 1, s.focus + step));
        s.scroll = NH.offsetFor(s.scroll, Math.floor(s.focus / 2), NH.VISIBLE_ROWS, NH.rowsOf(n)); return null;
      }
      if (k === "START" || k === "TAP") return runNew(s.tiles[s.focus], s);
      if (k === "MENU") return null;
      return undefined;
    }
  };
  SIM_VIEWS["new:homeList"] = {
    newDesign: true, title: "Home (b) hero list",
    init(o) { const s = baseInit(o); s.rows = NH.TILES.slice(); return s; },
    draw(dc, s) { NH.hero(dc, { rows: s.rows, focus: s.focus, msg: s.msg, shift: Ui.slideShift(s.slide, performance.now()) }); },
    key(k, s) {
      const n = s.rows.length;
      // The list wraps at both ends like Garmin's own menus (1.1.1; 1.1.0 opened Charging/Status past the ends).
      if (k === "UP") { slideTo(s, (s.focus - 1 + n) % n); return null; }
      if (k === "DOWN") { slideTo(s, (s.focus + 1) % n); return null; }
      if (k === "SWIPE_UP") { slideTo(s, Math.min(n - 1, s.focus + 1)); return null; }
      if (k === "SWIPE_DOWN") { slideTo(s, Math.max(0, s.focus - 1)); return null; }
      if (k === "START" || k === "TAP") return runNew(s.rows[s.focus], s);
      if (k === "MENU") return null;
      return undefined;
    }
  };

  // ---------------------------------------------------------------- engine (DOM-free)
  const placeholder = name => ({
    title: name + " (not built yet)", init() { return {}; },
    draw(dc) { dc.setColor(T.TEXT_1, T.BG); dc.clear(); dc.setColor(T.TEXT_2); dc.drawText(130, 100, "small", "Not built yet", J.CENTER); dc.drawText(130, 136, "xtiny", Ui.fit(dc, name, "xtiny", 180), J.CENTER); },
    key() { return undefined; }
  });
  const CONFIRM = {
    title: "Confirmation", init(o) { return { text: o.text, then: o.then }; },
    draw(dc, s) { Native.confirmation(dc, s.text); },
    key(k) { return k === "START" ? "yes" : (k === "DOWN" || k === "BACK") ? "no" : null; }
  };
  const viewOf = name => name === "__confirm" ? CONFIRM : (SIM_VIEWS[name] || placeholder(name));
  function countError(e) { window.__jsErrors = (window.__jsErrors || 0) + 1; try { document.body.dataset.jsErrors = window.__jsErrors; } catch (x) {} console.error(e); }
  function makeEntry(name, o) {
    const v = viewOf(name); let state;
    try { state = v.init(o || {}); } catch (e) { countError(e); state = { __err: String(e && e.message || e) }; }
    return { name, state };
  }
  // A watch: {side, stack, toast, last, note, root, opts}.
  SIM.newWatch = (side, root, opts) => { const w = { side, root, opts: opts || {}, stack: [], toast: null, last: "", note: "", onChange: null }; SIM.reset(w); return w; };
  SIM.reset = w => { w.stack = [makeEntry(w.root, w.opts)]; w.toast = null; w.last = ""; w.note = ""; };
  SIM.top = w => w.stack[w.stack.length - 1];
  function resume(w) { const t = SIM.top(w), v = viewOf(t.name); if (v.resume) try { v.resume(t.state); } catch (e) { countError(e); } }
  function apply(w, res, from) {
    if (!res) return;
    if (Array.isArray(res)) { res.forEach(r => apply(w, r, from)); return; }
    if (res.pop) { if (w.stack.length > 1) { w.stack.pop(); resume(w); } else w.note = "exit app"; }
    if (res.replace) w.stack[w.stack.length - 1] = makeEntry(res.replace, Object.assign({}, w.opts, res.o));
    if (res.push) w.stack.push(makeEntry(res.push, Object.assign({}, w.opts, res.o)));
    if (res.confirm) w.stack.push({ name: "__confirm", state: { text: res.confirm.text, then: res.confirm.then } });
    if (res.toast) w.toast = { text: res.toast.text, icon: res.toast.icon, at: Date.now() };
  }
  // Sends one input; returns true when a toast was raised (the DOM layer arms its 2 s timer).
  SIM.send = (w, k) => {
    w.last = k; w.note = "";
    const hadToast = !!w.toast; w.toast = null;
    const t = SIM.top(w), v = viewOf(t.name);
    if (t.state && t.state.__err) { if (k === "BACK") apply(w, { pop: true }); return false; }
    if (t.name === "__confirm") {
      const r = CONFIRM.key(k);
      if (r) {
        const then = t.state.then; w.stack.pop(); resume(w);
        if (r === "yes" && then) { try { apply(w, typeof then === "function" ? then(SIM.top(w).state) : then); } catch (e) { countError(e); } }
      }
      return !!w.toast;
    }
    let res;
    try { res = v.key(k, t.state); } catch (e) { countError(e); t.state.__err = String(e && e.message || e); return false; }
    if (k === "BACK" && res === undefined) res = { pop: true };
    apply(w, res);
    void hadToast;
    return !!w.toast;
  };
  SIM.draw = (w, dc) => {
    const t = SIM.top(w), v = viewOf(t.name);
    const under = d => {
      if (t.state && t.state.__err) throw new Error(t.state.__err);
      d.setColor(T.TEXT_1, T.BG); v.draw(d, t.state);
    };
    try { if (w.toast) Native.toast(dc, under, w.toast); else under(dc); }
    catch (e) {
      if (!(t.state && t.state.__err)) { countError(e); t.state.__err = String(e && e.message || e); }
      dc.clearClip && dc.clearClip(); dc.mono = false;
      dc.setColor("#FFFFFF", "#AA0000"); dc.clear(); dc.setColor("#FFFFFF");
      dc.drawText(130, 96, "small", "View error", J.CENTER);
      dc.drawText(130, 132, "xtiny", Ui.fit(dc, t.name, "xtiny", 180), J.CENTER);
      dc.drawText(130, 152, "xtiny", Ui.fit(dc, t.state.__err || String(e), "xtiny", 170), J.CENTER);
    }
  };
  SIM.screenName = w => { const t = SIM.top(w), v = viewOf(t.name); return v.title && !t.name.startsWith("__") ? v.title + " · " + t.name : (v.title || t.name); };
  SIM.parseReplay = hash => {
    const out = { old: [], new: [], cfg: {} };
    const m = /^#sim=(.*)$/.exec(hash || ""); if (!m) return null;
    decodeURIComponent(m[1]).split(";").forEach(part => {
      const i = part.indexOf(":"); if (i < 0) return;
      const side = part.slice(0, i).trim().toLowerCase(), body = part.slice(i + 1);
      if (side === "cfg") body.split(",").forEach(kv => { const [a, b] = kv.split("="); if (a && b) out.cfg[a.trim()] = b.trim(); });
      else if (side === "old" || side === "new") out[side] = body.split(",").map(x => x.trim().toUpperCase()).filter(x => K.includes(x));
    });
    return out;
  };

  // ---------------------------------------------------------------- DOM layer
  const CSS = `
.sim-root { --sim-ink: var(--ink, #1d1f22); --sim-ink2: var(--ink-2, #565a60); --sim-rule: var(--rule, #d3d0ca); --sim-surface: var(--surface, #f7f6f3); --sim-accent: var(--accent, #0077b6);
  border: 1px solid var(--sim-rule); background: var(--sim-surface); color: var(--sim-ink); border-radius: 10px; padding: 14px 16px; outline: none; max-width: 100%; box-sizing: border-box; }
.sim-root:focus-visible { box-shadow: 0 0 0 2px var(--sim-accent); }
.sim-bar { display: flex; flex-wrap: wrap; gap: 8px 18px; align-items: center; font-size: 13px; margin-bottom: 10px; }
.sim-bar fieldset { border: 0; padding: 0; margin: 0; display: flex; gap: 8px; align-items: center; }
.sim-bar legend { float: left; font-weight: 600; margin-right: 6px; padding: 0; color: var(--sim-ink2); }
.sim-bar label { display: inline-flex; gap: 4px; align-items: center; cursor: pointer; white-space: nowrap; }
.sim-bar button { font: inherit; padding: 3px 10px; border: 1px solid var(--sim-rule); border-radius: 6px; background: transparent; color: var(--sim-ink); cursor: pointer; }
.sim-bar button:hover { border-color: var(--sim-accent); }
.sim-watches { display: flex; flex-wrap: wrap; gap: 20px 32px; justify-content: center; }
.sim-watch { margin: 0; display: flex; flex-direction: column; align-items: center; max-width: 100%; }
.sim-watch h4 { margin: 0 0 4px; font: 600 12px/1 "JetBrains Mono", ui-monospace, monospace; letter-spacing: .06em; color: var(--sim-ink2); }
.sim-watch.sim-active h4 { color: var(--sim-accent); }
.sim-face { position: relative; flex: none; touch-action: none; user-select: none; -webkit-user-select: none; }
.sim-face svg.bezel { position: absolute; inset: 0; width: 100%; height: 100%; }
.sim-face canvas { position: absolute; border-radius: 50%; image-rendering: pixelated; background: #000; cursor: grab; }
.sim-btn { position: absolute; border: 0; padding: 0; margin: 0; background: transparent; border-radius: 50%; cursor: pointer; }
.sim-btn:hover, .sim-btn:focus-visible { background: rgba(0, 170, 255, .18); outline: none; }
.sim-btn.sim-inert { cursor: default; }
.sim-btn.sim-inert:hover { background: transparent; }
.sim-cap { font: 12px/1.4 "JetBrains Mono", ui-monospace, monospace; color: var(--sim-ink2); margin-top: 4px; text-align: center; max-width: 100%; overflow-wrap: anywhere; }
.sim-cap b { color: var(--sim-ink); font-weight: 500; }
.sim-help { font-size: 12px; color: var(--sim-ink2); margin: 10px 0 0; }
@media (max-width: 520px) { .sim-root { padding: 12px; } }
`;
  const BUTTONS = [{ k: "LIGHT", deg: 300 }, { k: "UP", deg: 270 }, { k: "DOWN", deg: 240 }, { k: "START", deg: 60 }, { k: "BACK", deg: 120 }];

  SIM.mount = function () {
    const host = document.getElementById("sim"); if (!host) return;
    if (!document.getElementById("sim-style")) { const st = document.createElement("style"); st.id = "sim-style"; st.textContent = CSS; document.head.appendChild(st); }
    const cfg = { variant: "b", d2: "separate", d4: "refresh", d7: "arc", linked: true, active: "new" };
    const rp = SIM.parseReplay(location.hash);
    if (rp) Object.assign(cfg, rp.cfg);

    host.innerHTML = "";
    const root = document.createElement("section"); root.className = "sim-root"; root.tabIndex = 0;
    root.setAttribute("aria-label", "Interactive watches. Arrow up and down, Enter for START, Escape for BACK, M for MENU.");
    const radio = (name, legend, opts) => `<fieldset><legend>${legend}</legend>${opts.map(([v, l]) => `<label><input type="radio" name="sim-${name}" value="${v}"${cfg[name] === v ? " checked" : ""}> ${l}</label>`).join("")}</fieldset>`;
    root.innerHTML = `<div class="sim-bar">
      <label><input type="checkbox" class="sim-link"${cfg.linked ? " checked" : ""}> Link inputs</label>
      ${radio("variant", "NEW home", [["a", "a · grid"], ["b", "b · hero list"]])}
      ${radio("d2", "D2", [["separate", "separate"], ["merged", "merged"]])}
      ${radio("d4", "D4 START", [["refresh", "refresh"], ["menu", "menu"]])}
      ${radio("d7", "D7", [["arc", "arc"], ["dots", "dots"]])}
      <button type="button" class="sim-reset">Reset</button></div>
      <div class="sim-watches"></div>
      <p class="sim-help">Click the bezel buttons (hold UP 0.6 s = MENU) or drag on the screen (swipe up/down, short = tap). With this panel focused: ↑ ↓, Enter = START, Esc/Backspace = BACK, M = MENU.</p>`;
    host.appendChild(root);
    const wrapEl = root.querySelector(".sim-watches");
    const newRoot = () => cfg.variant === "a" ? "new:homeGrid" : "new:homeList";
    const newOpts = () => ({ variant: cfg.variant, d2: cfg.d2, d4: cfg.d4, d7: cfg.d7 });
    const watches = { old: SIM.newWatch("old", "old:home", {}), new: SIM.newWatch("new", newRoot(), newOpts()) };
    let replaying = false;

    function render(w) {
      const ctx = w.ctx; ctx.setTransform(1, 0, 0, 1, 0, 0);
      const dc = new Dc(ctx, 260, 260); dc.mono = w.side === "new" && !!OPT.mono;
      ctx.save(); SIM.draw(w, dc); dc.clearClip(); ctx.restore(); ctx.setTransform(1, 0, 0, 1, 0, 0);
      if (OPT.guides) guides(dc);
      w.cap.innerHTML = `last input <b>${w.last || "none"}</b>${w.note ? ` · <b>${w.note}</b>` : ""}<br>screen <b>${SIM.screenName(w)}</b>`;
      w.fig.classList.toggle("sim-active", !cfg.linked && cfg.active === w.side);
      // Keep drawing while a list slides (Ui.slideShift); one frame per animation frame.
      const st = SIM.top(w).state;
      if (st && st.slide && performance.now() - st.slide.t0 < Ui.SLIDE_MS && !w.raf) {
        w.raf = requestAnimationFrame(() => { w.raf = 0; render(w); });
      }
    }
    function input(w, k) {
      const toast = SIM.send(w, k);
      if (toast && !replaying) {
        clearTimeout(w.timer); const at = w.toast.at;
        w.timer = setTimeout(() => { if (w.toast && w.toast.at === at) { w.toast = null; render(w); } }, 2000);
      }
      render(w);
    }
    function dispatch(k, side) {
      if (cfg.linked) { input(watches.old, k); input(watches.new, k); }
      else { cfg.active = side || cfg.active; input(watches[cfg.active], k); render(watches.old); render(watches.new); }
    }

    // Builds both watch faces at the current OPT.scale; watch state (stacks, toasts) is kept.
    function buildFaces() {
    const scale = OPT.scale && OPT.scale !== 1 ? OPT.scale : 1.25;
    const d = Math.round(260 * scale), ring = d * 0.14, size = Math.round(d + ring * 2);
    wrapEl.innerHTML = "";
    for (const side of ["old", "new"]) {
      const w = watches[side];
      const fig = document.createElement("figure"); fig.className = "sim-watch";
      fig.innerHTML = `<h4>${side.toUpperCase()}</h4>`;
      const face = document.createElement("div"); face.className = "sim-face"; face.style.width = face.style.height = size + "px";
      face.innerHTML = bezelSvg(d);
      const cv = document.createElement("canvas"); cv.width = 260; cv.height = 260;
      cv.style.width = cv.style.height = d + "px"; cv.style.left = cv.style.top = ring + "px";
      cv.setAttribute("aria-label", side.toUpperCase() + " watch screen");
      face.appendChild(cv);
      // Buttons: same geometry as bezelSvg (deg clockwise from 12 o'clock).
      const c = size / 2, rb = d / 2 + ring * 0.9 + d * 0.035, hit = Math.round(d * 0.17);
      for (const b of BUTTONS) {
        const a = (b.deg - 90) * Math.PI / 180, x = c + rb * Math.cos(a), y = c + rb * Math.sin(a);
        const el = document.createElement("button"); el.type = "button"; el.className = "sim-btn" + (b.k === "LIGHT" ? " sim-inert" : "");
        el.style.left = Math.round(x - hit / 2) + "px"; el.style.top = Math.round(y - hit / 2) + "px"; el.style.width = el.style.height = hit + "px";
        el.title = b.k === "UP" ? "UP (hold for MENU)" : b.k === "LIGHT" ? "LIGHT (no action)" : b.k;
        el.setAttribute("aria-label", el.title);
        if (b.k !== "LIGHT") {
          let held = null, fired = false;
          el.addEventListener("pointerdown", e => {
            e.preventDefault(); root.focus({ preventScroll: true }); fired = false;
            if (b.k === "UP") held = setTimeout(() => { fired = true; dispatch("MENU", side); }, 600);
          });
          el.addEventListener("pointerup", e => {
            e.preventDefault(); clearTimeout(held);
            if (!(b.k === "UP" && fired)) dispatch(b.k, side);
          });
          el.addEventListener("pointerleave", () => clearTimeout(held));
          el.addEventListener("keydown", e => { if (e.key === " " || e.key === "Enter") { e.preventDefault(); e.stopPropagation(); dispatch(b.k, side); } });
        }
        face.appendChild(el);
      }
      // Screen: drag > 30 px = swipe, shorter = tap.
      let y0 = null;
      cv.addEventListener("pointerdown", e => { e.preventDefault(); y0 = e.clientY; try { cv.setPointerCapture(e.pointerId); } catch (x) {} root.focus({ preventScroll: true }); });
      cv.addEventListener("pointerup", e => {
        if (y0 == null) return; const dy = e.clientY - y0; y0 = null;
        dispatch(Math.abs(dy) > 30 ? (dy < 0 ? "SWIPE_UP" : "SWIPE_DOWN") : "TAP", side);
      });
      cv.addEventListener("pointercancel", () => { y0 = null; });
      const cap = document.createElement("div"); cap.className = "sim-cap";
      fig.appendChild(face); fig.appendChild(cap); wrapEl.appendChild(fig);
      Object.assign(w, { ctx: cv.getContext("2d"), cap, fig });
    }
    }
    buildFaces();

    root.addEventListener("keydown", e => {
      if (e.target !== root) return;
      const k = { ArrowUp: "UP", ArrowDown: "DOWN", Enter: "START", Escape: "BACK", Backspace: "BACK", m: "MENU", M: "MENU" }[e.key];
      if (!k) return; e.preventDefault(); dispatch(k);
    });
    function resetAll() {
      for (const w of Object.values(watches)) clearTimeout(w.timer);
      SIM.reset(watches.old);
      watches.new.root = newRoot(); watches.new.opts = newOpts(); SIM.reset(watches.new);
      render(watches.old); render(watches.new);
    }
    root.querySelector(".sim-link").addEventListener("change", e => { cfg.linked = e.target.checked; render(watches.old); render(watches.new); });
    root.querySelector(".sim-reset").addEventListener("click", resetAll);
    root.querySelectorAll('.sim-bar input[type="radio"]').forEach(r => r.addEventListener("change", e => {
      cfg[e.target.name.slice(4)] = e.target.value;
      // NEW options reach every pushed view, so a change restarts the NEW watch from home.
      clearTimeout(watches.new.timer); watches.new.root = newRoot(); watches.new.opts = newOpts(); SIM.reset(watches.new); render(watches.new);
    }));

    function replay(p) {
      replaying = true;
      try { for (const side of ["old", "new"]) for (const k of p[side]) input(watches[side], k); } finally { replaying = false; }
    }
    render(watches.old); render(watches.new);
    if (rp) replay(rp);
    window.addEventListener("hashchange", () => {
      const p = SIM.parseReplay(location.hash); if (!p) return;
      Object.assign(cfg, p.cfg);
      root.querySelectorAll('.sim-bar input[type="radio"]').forEach(r => { r.checked = cfg[r.name.slice(4)] === r.value; });
      resetAll(); replay(p);
    });
    SIM.watches = watches;
    // Called by the page shell when toolbar options (scale, mono, guides) change.
    SIM.refresh = () => { buildFaces(); render(watches.old); render(watches.new); };
  };

  window.SIM = SIM;
})();
