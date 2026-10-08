// ================================================================ Boot (agent E)
// Error counter (also started in 00-head), fonts, calibrate, toolbar, board, simulator, deep link.
window.__jsErrors = window.__jsErrors || 0;
function __boot() {
  const err = e => { window.__jsErrors++; console.error(e); };
  try { calibrate(); } catch (e) { err(e); }
  try { Board.wire(); } catch (e) { err(e); }
  try { Board.build(); } catch (e) { err(e); }
  try { if (window.SIM && typeof SIM.mount === "function") SIM.mount(); } catch (e) { err(e); }
  window.__booted = true;
  document.body.dataset.jsErrors = window.__jsErrors;
  if (location.hash.length > 1) {
    let t = null; try { t = document.getElementById(decodeURIComponent(location.hash.slice(1))); } catch (e) {}
    if (t) requestAnimationFrame(() => t.scrollIntoView({ block: "start", behavior: "instant" }));
  }
}
document.body.dataset.jsErrors = window.__jsErrors;
Promise.all([
  document.fonts.load("700 20px Roboto"), document.fonts.load("700 20px 'Roboto Condensed'"),
  document.fonts.load("700 20px 'Barlow Semi Condensed'")
]).catch(() => {}).finally(() => document.fonts.ready.then(__boot, __boot));
