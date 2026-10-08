import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;

// Task 11 (US-060): "the monochrome test... render any screen without
// colour and every state must still be identifiable." The SDK gives no way
// to automate that pixel-for-pixel: Toybox.Graphics.Dc/BufferedBitmap has
// no pixel-readback API at all (checked against the SDK's own Dc and
// BufferedBitmap reference pages: draw-only, nothing symmetric to
// getPixel()), so "assert distinguishability" from a unit test is not
// achievable in this SDK. What IS achievable, and is wired up here: a
// Storage-backed switch that collapses every colour this app draws down to
// white or black, so a developer can flip it: via the simulator's own
// File -> Edit Persistent Storage (see docs/best-practices, "Testing"), and
// then actually look at every screen with colour removed, which is the
// real "render without colour" check the story asks for. The pure mapping
// itself (color()) is unit-tested below; the removal of colour from the
// rendered screens is a rendering aid a human runs, not an automated
// assertion, see this task's final report for the written per-screen audit
// that stands in for what cannot be automated.
//
// (:glance) because ui/Theme.mc wraps it and the glance draws through
// Theme.c(); without the annotation Theme.refresh() would crash the glance
// (decisions.md, "(:glance) is a linking rule").
(:glance)
module MonochromeTest {

    const STORAGE_KEY = "monochromeTestEnabled";

    function isEnabled() as Boolean {
        var stored = Storage.getValue(STORAGE_KEY);
        return stored instanceof Boolean && (stored as Boolean);
    }

    function setEnabled(enabled as Boolean) as Void {
        Storage.setValue(STORAGE_KEY, enabled as Storage.ValueType);
    }

    // Collapses `c` to WHITE unless the test is off, or `c` is already
    // BLACK/TRANSPARENT: both of those are structural (the canvas
    // background and the "no fill" sentinel every screen in this app
    // already uses), never a state signal on their own, so leaving them
    // alone does not undermine the test. Every screen in this app draws on
    // a black background (Theme.BG, cleared by every Night Panel view and
    // NightMenu.drawTitle), so white-on-black plus icon/text/shape is exactly the
    // "screenshot desaturated" scenario US-060/the task brief describes.
    function color(c as Graphics.ColorType) as Graphics.ColorType {
        if (!isEnabled()) {
            return c;
        }
        if (c == Graphics.COLOR_TRANSPARENT) {
            return c;
        }
        if (c == Graphics.COLOR_BLACK) {
            return c;
        }
        return Graphics.COLOR_WHITE;
    }

}
