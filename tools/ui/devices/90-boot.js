// ================================================================ DEVICES: boot
// Fonts, calibration, hook check, column check, self-test, toolbar, board, deep link.
window.__jsErrors = window.__jsErrors || 0;
function __devBoot() {
  const err = e => { window.__jsErrors++; console.error(e); };
  try { calibrate(); } catch (e) { err(e); }
  try { DevRender.captureOriginals(); } catch (e) { err(e); }
  try { const miss = DevRender.missingHooks(); document.body.dataset.hookMissing = miss.join(" "); if (miss.length) err(new Error("poc names the devices page hooks are missing: " + miss.join(", "))); } catch (e) { err(e); }
  try { const bad = DEV.validate(); if (bad.length) err(new Error("columns do not match DEV_DATA: " + bad.join("; "))); } catch (e) { err(e); }
  try { const d = DevRender.selftest(); document.body.dataset.selftest = d === 0 ? "pass" : "fail:" + d; } catch (e) { err(e); document.body.dataset.selftest = "error"; }
  try { DevBoard.wire(); } catch (e) { err(e); }
  try { DevBoard.build(); } catch (e) { err(e); }
  window.__booted = true;
  document.body.dataset.booted = "1";
  document.body.dataset.jsErrors = window.__jsErrors;
  if (location.hash.length > 1) {
    let t = null; try { t = document.getElementById(decodeURIComponent(location.hash.slice(1))); } catch (e) {}
    if (t) requestAnimationFrame(() => t.scrollIntoView({ block: "start", behavior: "instant" }));
  }
}
document.body.dataset.jsErrors = window.__jsErrors;
Promise.all([
  document.fonts.load("700 20px Roboto"), document.fonts.load("400 20px Roboto"), document.fonts.load("900 20px Roboto"),
  document.fonts.load("700 20px 'Roboto Condensed'"), document.fonts.load("600 20px 'Roboto Condensed'"),
  document.fonts.load("400 20px Yantramanav"), document.fonts.load("700 20px 'Barlow Semi Condensed'")
]).catch(() => {}).finally(() => document.fonts.ready.then(__devBoot, __devBoot));
