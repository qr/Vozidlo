import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Screen geometry for every supported watch (decisions.md "Layouts follow
// the screen"). The Night Panel was drawn for the 260 px round fēnix; every
// other watch gets the same layout scaled by s = width / 260, with the y
// positions stacked from its own measured font heights, so on the fēnix 7
// Pro every token below is exactly the number the screens used before.
//
// Built once from System.getDeviceSettings() and Graphics.getFontHeight(),
// no Dc needed (current()). make() is pure, so tests run the layout of any
// watch on one simulator (tests/GeoTests.mc holds the fixtures). The spec
// lives in tools/ui/devices/20-render.js geometry() and 40-screens.js DS.*.
//
// App scope only, deliberately not (:glance): the glance does its own
// scaling, and this module would cost the 64 KB glance arena for nothing.
module Geo {

    // Input profiles (docs/adding-a-watch.md): A five buttons (fēnix,
    // Forerunner), B START + BACK with MENU = hold BACK (Venu 3 / 3S),
    // C START + BACK without MENU, so Garmin's action menu indicator and
    // onActionMenu stand in for it (vívoactive 6, Venu 4, Venu X1).
    const INPUT_A = 0;
    const INPUT_B = 1;
    const INPUT_C = 2;

    // Button positions on a round bezel, canvas degrees (0 = 3 o'clock,
    // clockwise; Bezel.ciqDegrees() converts for Dc.drawArc).
    const ANGLE_START = -30;
    const ANGLE_BACK = 30;
    const ANGLE_DOWN = 150;
    const ANGLE_UP = 180;

    // The design's logical width: every k below is in px of a 260 face.
    const LOGICAL_W = 260;

    // Measured font heights (Graphics.getFontHeight), the only typography
    // the layout needs to stack lines.
    class Fonts {
        public var xtinyH as Number;
        public var tinyH as Number;
        public var smallH as Number;
        public var mediumH as Number;
        public var numMildH as Number;
        public var numMedH as Number;

        function initialize(xtiny as Number, tiny as Number, small as Number, medium as Number,
                            numMild as Number, numMed as Number) {
            xtinyH = xtiny;
            tinyH = tiny;
            smallH = small;
            mediumH = medium;
            numMildH = numMild;
            numMedH = numMed;
        }
    }

    // One display and every layout token, in device px.
    class Display {
        public var w as Number;
        public var h as Number;
        public var cx as Number;
        public var cy as Number;
        // Half the width: the radius on a round face.
        public var R as Number;
        public var round as Boolean;
        public var s as Float;
        public var input as Number;
        public var touch as Boolean;
        public var fonts as Fonts;
        // Display corner radius on a rectangle (0 on round faces).
        public var corner as Number;
        // Garmin's action menu indicator as [x, y, w, h], INPUT_C only.
        public var hint as Array<Number>?;
        // Whether the indicator is on screen now (setKeepOut): text then
        // stays left of it inside its band.
        public var keepOut as Boolean = false;

        // Status/Charging title top (SG §5 y 34).
        public var titleTop as Number = 0;
        // Status age line top, and the Charging age line top.
        public var statusTop as Number = 0;
        public var chargingAgeTop as Number = 0;
        // Chips.height(): at least 20 px (B4), more when FONT_XTINY is taller.
        public var chipH as Number = 0;
        // NightMenu row pitch. On the button watches a list shows three
        // rows: the focused one in the middle and one above and below. Rows
        // sized from the font (53 to 55 px, 1.1.0) fitted five on a 260 px
        // display with the outer two in the round edge; a third of the
        // display (80 px, 1.1.1) spread three over the whole face. A quarter
        // of the display (65 px) keeps them close; the rows two away would
        // show in the edge at that pitch, so NightMenu masks that edge
        // (NightMenuLayout.maskBands). The scroll watches show every row
        // (NightMenuLayout.masks). System fonts scale on fēnix 8/9 (0.8
        // to 1.45), so the row never drops under FONT_MEDIUM plus 16 px for
        // the focus pill.
        public var rowH as Number = 0;
        // Bottom of the home hero: the focused row is centred, so the
        // CustomMenu title ends half a row above the centre at focus 0.
        public var heroBottom as Number = 0;
        // Highest top for hero digits before they meet the ring.
        public var minDigitTop as Number = 0;
        // Hero number font for the whole watch (M1) and its unit font.
        public var heroFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
        public var unitFont as Graphics.FontType = Graphics.FONT_MEDIUM;
        // Bezel radii: SoC ring and its pen, button glyphs and their icon
        // radius, page dots, Find my car track and the text inside it.
        public var ringR as Number = 0;
        public var ringPen as Number = 0;
        public var glyphR as Number = 0;
        public var glyphIconR as Number = 0;
        public var dotsR as Number = 0;
        public var trackR as Number = 0;
        public var textR as Number = 0;

        function initialize(width as Number, height as Number, isRound as Boolean, inputProfile as Number,
                            isTouch as Boolean, fontHeights as Fonts) {
            w = width;
            h = height;
            cx = width / 2;
            cy = height / 2;
            R = width / 2;
            round = isRound;
            s = width.toFloat() / LOGICAL_W;
            input = inputProfile;
            touch = isTouch;
            fonts = fontHeights;
            corner = isRound ? 0 : Geo.cornerFor(width, height);
            hint = Geo.hintFor(isRound, width, height, inputProfile);

            // On a rectangle the 260 square sits in the middle of the
            // frame, so tokens anchored on its top/bottom move to the edges.
            var xt = fontHeights.xtinyH;
            titleTop = px(isRound ? 34 : 20);
            statusTop = height - px(isRound ? 29 : 20) - xt;
            chargingAgeTop = height - px(isRound ? 39 : 30) - xt;
            var c = xt + px(2);
            var minChip = px(20);
            chipH = c > minChip ? c : minChip;
            var r = height / 4;
            var minRow = fontHeights.mediumH + 16;
            rowH = r > minRow ? r : minRow;
            heroBottom = cy - rowH / 2;
            minDigitTop = px(12);
            ringR = R - px(4);
            ringPen = px(4);
            glyphR = R - px(22);
            glyphIconR = px(6);
            dotsR = R - px(12);
            trackR = R - px(5);
            textR = R - px(6);
            heroFont = Geo.heroFontFor(self);
            unitFont = heroFont == Graphics.FONT_NUMBER_MEDIUM ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        }

        // A length of k px on the 260 face, in device px. Exact at s = 1.
        function px(k as Numeric) as Number {
            return Math.round(k * s).toNumber();
        }

        // Half the width of the display outline at vertical distance dy
        // from the centre, truncated like TextBlock.halfChord.
        function halfChord(dy as Number) as Number {
            if (round) {
                return TextBlock.halfChord(R, dy);
            }
            return TextBlock.roundedRectHalfChord(w / 2, h / 2, corner, dy);
        }

        // [left, right] of a glyph box from top to bottom, margin in 260 px
        // (scaled here). The binding edge is whichever is further from the
        // middle, as in TextBlock.lineWidth. While the action menu indicator
        // shows (keepOut) and the box overlaps its band, only the right
        // bound moves, to px(8) left of the indicator, so a grid can shift
        // left instead of shrinking on both sides.
        function span(top as Number, bottom as Number, margin as Number) as [Number, Number] {
            var dTop = (top - cy).abs();
            var dBottom = (bottom - cy).abs();
            var half = halfChord(dTop > dBottom ? dTop : dBottom) - px(margin);
            if (half < 0) {
                half = 0;
            }
            var left = cx - half;
            var right = cx + half;
            var band = hint;
            if (keepOut && band != null && bottom > band[1] && top < band[1] + band[3]) {
                var limit = (band[0] as Number) - px(8);
                if (right > limit) {
                    right = limit > left ? limit : left;
                }
            }
            return [left, right];
        }

        // Usable width for a box centred on cx (Ui.usable). At s = 1 on the
        // round face this is TextBlock.lineWidth - 2 * (margin - 8), today's
        // value. Under the keep-out a centred box can only use twice the
        // room right of the centre; span() gives the shifted room.
        function usable(top as Number, bottom as Number, margin as Number) as Number {
            var sp = span(top, bottom, margin);
            var a = cx - sp[0];
            var b = sp[1] - cx;
            var half = a < b ? a : b;
            return half > 0 ? 2 * half : 0;
        }

        // Whether the watch has this button: START and BACK everywhere, UP
        // and DOWN on the five-button watches only (profile A).
        function hasButton(pos as Symbol) as Boolean {
            if (pos == :start || pos == :back) {
                return true;
            }
            if (pos == :up || pos == :down) {
                return input == Geo.INPUT_A;
            }
            return false;
        }

        // Where a glyph for a button goes: on the glyph radius at the button
        // angle (round), or next to the key on the right edge (rectangle).
        // null for a button this watch does not have.
        function anchor(pos as Symbol) as [Number, Number]? {
            if (!hasButton(pos)) {
                return null;
            }
            if (round) {
                return Bezel.polarAt(cx, cy, glyphR, Geo.buttonAngle(pos));
            }
            var y = keyY(pos);
            return y != null ? [w - px(22), y] : null;
        }

        // Screen y of a button's key: a quarter and three quarters down the
        // right edge on the rectangle (START, BACK), the glyph anchor's y on
        // a round face. null for a button this watch does not have.
        function keyY(pos as Symbol) as Number? {
            if (!hasButton(pos)) {
                return null;
            }
            if (!round) {
                if (pos == :start) {
                    return h / 4;
                }
                return pos == :back ? 3 * h / 4 : null;
            }
            return Bezel.polarAt(cx, cy, glyphR, Geo.buttonAngle(pos))[1];
        }
    }

    var _current as Display? = null;

    // ------------------------------------------------------------ pure

    function make(w as Number, h as Number, round as Boolean, input as Number, touch as Boolean,
                  fonts as Fonts) as Display {
        return new Display(w, h, round, input, touch, fonts);
    }

    // Profile from DeviceSettings.inputButtons: an UP key means the five
    // buttons (A), else a MENU key means hold BACK (B), else none (C).
    function inputFrom(buttons as Number) as Number {
        if ((buttons & System.BUTTON_INPUT_UP) != 0) {
            return INPUT_A;
        }
        if ((buttons & System.BUTTON_INPUT_MENU) != 0) {
            return INPUT_B;
        }
        return INPUT_C;
    }

    // Canvas angle of a button on a round bezel.
    function buttonAngle(pos as Symbol) as Number {
        if (pos == :back) {
            return ANGLE_BACK;
        }
        if (pos == :down) {
            return ANGLE_DOWN;
        }
        if (pos == :up) {
            return ANGLE_UP;
        }
        return ANGLE_START;
    }

    // Garmin's action menu indicator rect, [x, y, w, h] in device px, on
    // profile C only. No runtime API reports it, so the values are copied
    // per screen from the device files (simulator.json, layouts actionMenu
    // actionMenuHint), with the 390 round one scaled for a screen not in
    // this table.
    function hintFor(round as Boolean, w as Number, h as Number, input as Number) as Array<Number>? {
        if (input != INPUT_C) {
            return null;
        }
        if (round && w == 390 && h == 390) {
            return [361, 156, 22, 91] as Array<Number>;
        }
        if (round && w == 454 && h == 454) {
            return [420, 176, 28, 106] as Array<Number>;
        }
        if (!round && w == 448 && h == 486) {
            return [422, 190, 26, 106] as Array<Number>;
        }
        return [361 * w / 390, 156 * h / 390, 22 * w / 390, 91 * h / 390] as Array<Number>;
    }

    // Display corner radius of a rectangle in device px: 58 on the Venu X1,
    // estimated from the simulator artwork (not in the device files), and
    // proportional to the width on a rectangle not measured yet.
    function cornerFor(w as Number, h as Number) as Number {
        if (w == 448 && h == 486) {
            return 58;
        }
        return 58 * w / 448;
    }

    // The Charging worst case decides the hero number font for the whole
    // watch (M1): title, hero, chip and two lines must clear the age line.
    // numMed where that fits, else numMild.
    function heroFontFor(d as Display) as Graphics.FontType {
        var f = d.fonts;
        var heights = [f.numMedH, f.numMildH] as Array<Number>;
        for (var i = 0; i < heights.size(); i += 1) {
            var heroTop = d.titleTop + f.tinyH - d.px(5);
            var chipTop = heroTop + (heights[i] as Number) + d.px(2);
            var rows = chipTop + d.chipH + d.px(5);
            var bottom = rows + 2 * (f.xtinyH + d.px(1)) - d.px(1);
            if (bottom + d.px(2) <= d.chargingAgeTop) {
                return i == 0 ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;
            }
        }
        return Graphics.FONT_NUMBER_MILD;
    }

    // ------------------------------------------------------------ device

    // This watch, built once per app run (the display never changes).
    function current() as Display {
        var g = _current;
        if (g == null) {
            var ds = System.getDeviceSettings();
            g = make(ds.screenWidth, ds.screenHeight, ds.screenShape != System.SCREEN_SHAPE_RECTANGLE,
                inputFrom(ds.inputButtons), ds.isTouchScreen,
                new Fonts(Graphics.getFontHeight(Graphics.FONT_XTINY), Graphics.getFontHeight(Graphics.FONT_TINY),
                    Graphics.getFontHeight(Graphics.FONT_SMALL), Graphics.getFontHeight(Graphics.FONT_MEDIUM),
                    Graphics.getFontHeight(Graphics.FONT_NUMBER_MILD), Graphics.getFontHeight(Graphics.FONT_NUMBER_MEDIUM)));
            _current = g;
        }
        return g;
    }

    // Views set this in onShow from whether they enabled the indicator
    // (Input.enableIndicator); NightMenu always clears it.
    function setKeepOut(on as Boolean) as Void {
        current().keepOut = on;
    }

}
