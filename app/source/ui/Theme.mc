import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
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
    // one for screens with a ring at r 126 (C intro).
    const MARGIN = 8;
    const RING_MARGIN = 12;

    // Transitions (B6). Drill-in slides left, back slides right; Status comes
    // from below and Charging from above, matching the buttons that open them.
    const SLIDE_IN = WatchUi.SLIDE_LEFT;
    const SLIDE_OUT = WatchUi.SLIDE_RIGHT;
    const SLIDE_STATUS = WatchUi.SLIDE_UP;
    const SLIDE_CHARGING = WatchUi.SLIDE_DOWN;
    const SLIDE_DIALOG = WatchUi.SLIDE_IMMEDIATE;

    // Title area height for the home CustomMenu (the hero lives in the
    // title). At focus 0 only heroBottom() px of the title are on screen
    // (98 with rows of 65 on a 260 px display; see the header of
    // ui/NightMenu.mc for what the spike could and could not check), so the
    // title is exactly that tall and the hero lays out from its bottom up.
    const HOME_TITLE_H = 98;

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

    // Every list shows three rows: the focused one in the middle and one
    // above and below. Rows sized from the font (53 to 55 px, 1.1.0) fitted
    // five on a 260 px display, with the outer two in the round edge; rows of
    // a third of the display (80 px, 1.1.1) kept three but spread them over
    // the whole face. A quarter of the display (65 px) keeps the three close
    // together; the rows two away from the focus would show in the edge at
    // that pitch, so NightMenu leaves them blank (NightMenuLayout.isShown).
    // System fonts scale on fēnix 8/9 (0.8 to 1.45), so the row never drops
    // under FONT_MEDIUM plus 16 px for the focus pill.
    function rowHeight() as Number {
        var h = System.getDeviceSettings().screenHeight / 4;
        var min = Graphics.getFontHeight(Graphics.FONT_MEDIUM) + 16;
        return h > min ? h : min;
    }

    // Bottom edge of the home hero on screen: the focused row is centred, so
    // the CustomMenu title ends half a row above the centre at focus 0.
    function heroBottom() as Number {
        return 130 - rowHeight() / 2;
    }

}
