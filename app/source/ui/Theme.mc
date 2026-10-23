import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// "Night Panel" tokens (docs/design/ui-improvements.md B3). One accent, words
// before colour, and every colour goes through c() so the monochrome test
// (US-060) covers every screen without each view re-reading Storage.
//
// (:glance) because the glance draws with the same tokens; the module holds
// constants and one cached flag, so it costs the 64 KB glance arena little.
(:glance)
module Theme {

    const BG = 0x000000;
    // Lines, outlines and inactive dots; never text on a grey fill (B3).
    const RULE = 0x555555;
    const TEXT_1 = 0xFFFFFF;
    const TEXT_2 = 0xAAAAAA;
    // Škoda Electric Green #78FAAE as the 64-colour MIP panel shows it; exact
    // on all six targets. Owner decision 2026-10-07 (D3).
    const ACCENT = 0x55FFAA;
    // Škoda Emerald #0E3A2F as the panel shows it: too dark for an accent,
    // only used for sub-labels on the accent focus pill.
    const EMERALD = 0x005555;
    // Garmin's own success green; transient check icons and toasts only.
    const POSITIVE = 0x00FF00;
    // Unlocked, open, stale, connect cable; always paired with an icon or "!".
    const WARNING = 0xFFAA00;
    // Failed request, phone offline, stop-type confirmations; always with "!".
    const DESTRUCTIVE = 0xFF0000;

    // Default side margin inside the chord (TextBlock.MARGIN), and the wider
    // one for screens with a ring at r 126 (C intro). Both are in px of the
    // 260 face; Geo.Display.usable() scales them.
    //
    // Row height, hero bottom and the home title height moved to Geo
    // (ui/Geometry.mc), which is app scope: they depend on the screen.
    const MARGIN = 8;
    const RING_MARGIN = 12;

    // Transitions (B6). Drill-in slides left, back slides right; Status comes
    // from below and Charging from above, matching the buttons that open them.
    const SLIDE_IN = WatchUi.SLIDE_LEFT;
    const SLIDE_OUT = WatchUi.SLIDE_RIGHT;
    const SLIDE_STATUS = WatchUi.SLIDE_UP;
    const SLIDE_CHARGING = WatchUi.SLIDE_DOWN;
    const SLIDE_DIALOG = WatchUi.SLIDE_IMMEDIATE;

    var _mono as Boolean = false;

    // Reads the MonochromeTest switch once per onShow instead of per draw
    // call; Storage reads are cheap but not free, and onUpdate runs often.
    function refresh() as Void {
        _mono = MonochromeTest.isEnabled();
    }

    // For the few places that change shape, not only colour, under the
    // monochrome test (focus pill fill, emerald sub-label).
    function isMono() as Boolean {
        return _mono;
    }

    // Every colour a Night Panel screen draws passes through here so US-060's
    // monochrome check needs no per-view code: black stays black (canvas,
    // text on fills), anything else becomes white.
    function c(color as Number) as Number {
        if (!_mono) {
            return color;
        }
        if (color == BG || color == Graphics.COLOR_TRANSPARENT) {
            return color;
        }
        return TEXT_1;
    }

}
