import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Unit tests for ui/Geometry.mc. The fixtures below are the displays of the
// supported watches as Geo.make() builds them, with the font heights
// Graphics.getFontHeight returns in the SDK 9.2.0 simulator (the TOKENS
// line liveTokensMatchTheFixture logs per device). On the MIP watches they
// equal the .cft headers; on the AMOLED watches some are 1 px lower than
// the TrueType metrics, which is enough to flip the Venu 3S hero font.
// Other test modules reuse them, so every layout can be checked for every
// screen while the tests run on one simulator.
//
// The fēnix 7 Pro pins are today's numbers: the layout must not move a
// pixel there (decisions.md "Layouts follow the screen, measured from the
// Dc").
module GeoTests {

    // ------------------------------------------------------------ fixtures

    // fēnix 7 Pro (also fēnix 7 Pro no Wi-Fi): 260 round, five buttons.
    function fenix7pro() as Geo.Display {
        return Geo.make(260, 260, true, Geo.INPUT_A, true, new Geo.Fonts(19, 29, 32, 37, 60, 74));
    }

    // fēnix 7S / 7S Pro: 240 round, five buttons (.cft font heights).
    function fenix7s() as Geo.Display {
        return Geo.make(240, 240, true, Geo.INPUT_A, true, new Geo.Fonts(19, 26, 29, 34, 55, 67));
    }

    // fēnix 7X Pro: 280 round, five buttons (.cft font heights).
    function fenix7xpro() as Geo.Display {
        return Geo.make(280, 280, true, Geo.INPUT_A, true, new Geo.Fonts(19, 31, 34, 40, 64, 79));
    }

    // Forerunner 255 / 255 Music: 260 round, five buttons, no touch, smaller
    // number fonts.
    function fr255() as Geo.Display {
        return Geo.make(260, 260, true, Geo.INPUT_A, false, new Geo.Fonts(19, 29, 32, 37, 45, 53));
    }

    // Forerunner 255S / 255S Music: 218 round, five buttons, no touch; the
    // text fonts barely shrink from the 260 (xtiny is the same 19 px).
    function fr255s() as Geo.Display {
        return Geo.make(218, 218, true, Geo.INPUT_A, false, new Geo.Fonts(19, 23, 26, 32, 40, 53));
    }

    // Venu 3S: 390 round, START + BACK, MENU = hold BACK.
    function venu3s() as Geo.Display {
        return Geo.make(390, 390, true, Geo.INPUT_B, true, new Geo.Fonts(32, 40, 47, 53, 77, 100));
    }

    // vívoactive 5: 390 round, profile B like the Venu 3S, with bitmap fonts.
    function vivoactive5() as Geo.Display {
        return Geo.make(390, 390, true, Geo.INPUT_B, true, new Geo.Fonts(32, 41, 48, 54, 74, 99));
    }

    // Forerunner 265: 416 round, five buttons and touch.
    function fr265() as Geo.Display {
        return Geo.make(416, 416, true, Geo.INPUT_A, true, new Geo.Fonts(34, 43, 50, 58, 95, 117));
    }

    // Venu 3: 454 round, profile B.
    function venu3() as Geo.Display {
        return Geo.make(454, 454, true, Geo.INPUT_B, true, new Geo.Fonts(35, 45, 50, 58, 89, 116));
    }

    // vívoactive 6 (and Venu 4 41 mm): 390 round, no MENU key.
    function vivoactive6() as Geo.Display {
        return Geo.make(390, 390, true, Geo.INPUT_C, true, new Geo.Fonts(30, 35, 45, 53, 97, 130));
    }

    // Venu 4 45 mm: 454 round, no MENU key.
    function venu445mm() as Geo.Display {
        return Geo.make(454, 454, true, Geo.INPUT_C, true, new Geo.Fonts(37, 47, 53, 61, 112, 152));
    }

    // Venu X1: 448 x 486 rounded rectangle, no MENU key.
    function venux1() as Geo.Display {
        return Geo.make(448, 486, false, Geo.INPUT_C, true, new Geo.Fonts(37, 47, 53, 61, 112, 152));
    }

    // Every fixture above, for the tests that check a layout on every screen.
    // A new screen gets its fixture here and is then checked everywhere.
    function all() as Array<Geo.Display> {
        return [fenix7pro(), fenix7s(), fenix7xpro(), fr255(), fr255s(), venu3s(), vivoactive5(), fr265(), venu3(),
            vivoactive6(), venu445mm(), venux1()] as Array<Geo.Display>;
    }

    // ------------------------------------------------------------ helpers

    function _eq(logger as Logger, what as String, got as Number?, want as Number) as Boolean {
        if (got == null || got != want) {
            logger.error(what + ": expected " + want.toString() + ", got " + (got == null ? "null" : got.toString()));
            return false;
        }
        return true;
    }

    function _at(logger as Logger, what as String, got as [Number, Number]?, x as Number, y as Number) as Boolean {
        if (got == null || got[0] != x || got[1] != y) {
            logger.error(what + ": expected " + x.toString() + "," + y.toString() + ", got "
                + (got == null ? "null" : got[0].toString() + "," + got[1].toString()));
            return false;
        }
        return true;
    }

    // Every token, one line, for logs and the live comparison.
    function describe(g as Geo.Display) as String {
        return "w " + g.w + " h " + g.h + " round " + g.round + " input " + g.input + " touch " + g.touch
            + " fonts " + g.fonts.xtinyH + "/" + g.fonts.tinyH + "/" + g.fonts.smallH + "/" + g.fonts.mediumH
            + "/" + g.fonts.numMildH + "/" + g.fonts.numMedH
            + " titleTop " + g.titleTop + " statusTop " + g.statusTop + " chargingAgeTop " + g.chargingAgeTop
            + " chipH " + g.chipH + " rowH " + g.rowH + " heroBottom " + g.heroBottom + " minDigitTop " + g.minDigitTop
            + " hero " + (g.heroFont == Graphics.FONT_NUMBER_MEDIUM ? "numMed" : "numMild")
            + " ringR " + g.ringR + " ringPen " + g.ringPen + " glyphR " + g.glyphR + " glyphIconR " + g.glyphIconR
            + " dotsR " + g.dotsR + " trackR " + g.trackR + " textR " + g.textR;
    }

    // ------------------------------------------------------------ tests

    // Today's fēnix 7 Pro numbers, every one of them.
    (:test)
    function fenix7proTokensAreToday(logger as Logger) as Boolean {
        var g = fenix7pro();
        var ok = _eq(logger, "px(34)", g.px(34), 34) && _eq(logger, "px(193)", g.px(193), 193)
            && _eq(logger, "titleTop", g.titleTop, 34)
            && _eq(logger, "statusTop", g.statusTop, 212)
            && _eq(logger, "chargingAgeTop", g.chargingAgeTop, 202)
            && _eq(logger, "chipH", g.chipH, 21)
            && _eq(logger, "rowH", g.rowH, 65)
            && _eq(logger, "heroBottom", g.heroBottom, 98)
            && _eq(logger, "minDigitTop", g.minDigitTop, 12)
            && _eq(logger, "ringR", g.ringR, 126)
            && _eq(logger, "ringPen", g.ringPen, 4)
            && _eq(logger, "glyphR", g.glyphR, 108)
            && _eq(logger, "glyphIconR", g.glyphIconR, 6)
            && _eq(logger, "dotsR", g.dotsR, 118)
            && _eq(logger, "trackR", g.trackR, 125)
            && _eq(logger, "textR", g.textR, 124)
            && _eq(logger, "cx", g.cx, 130) && _eq(logger, "cy", g.cy, 130)
            && _at(logger, "anchor start", g.anchor(:start), 224, 76)
            && _at(logger, "anchor back", g.anchor(:back), 224, 184)
            && _at(logger, "anchor up", g.anchor(:up), 22, 130)
            && _at(logger, "anchor down", g.anchor(:down), 36, 184);
        if (!ok) {
            return false;
        }
        if (g.heroFont != Graphics.FONT_NUMBER_MEDIUM || g.unitFont != Graphics.FONT_MEDIUM) {
            logger.error("fēnix 7 Pro hero must be numberMedium with a medium unit");
            return false;
        }
        if (g.hint != null || g.corner != 0) {
            logger.error("a round five-button watch has no indicator and no corner");
            return false;
        }
        return true;
    }

    // At s = 1 the outline width is today's Ui.usable: TextBlock.lineWidth
    // minus the extra margin, for every box and margin the screens use.
    (:test)
    function fenix7proUsableIsTodays(logger as Logger) as Boolean {
        var g = fenix7pro();
        var boxes = [[34, 63], [58, 132], [120, 140], [181, 209], [202, 221], [0, 20], [240, 259]] as Array<Array<Number>>;
        var margins = [8, 12, 16] as Array<Number>;
        for (var i = 0; i < boxes.size(); i += 1) {
            var b = boxes[i] as Array<Number>;
            for (var j = 0; j < margins.size(); j += 1) {
                var m = margins[j] as Number;
                var want = TextBlock.lineWidth(130, 130, b[0] as Number, b[1] as Number) - 2 * (m - TextBlock.MARGIN);
                if (want < 0) {
                    want = 0;
                }
                if (!_eq(logger, "usable(" + b[0] + ", " + b[1] + ", " + m + ")", g.usable(b[0] as Number, b[1] as Number, m), want)) {
                    return false;
                }
            }
        }
        return true;
    }

    // M1: the Charging worst case picks the hero font per watch, re-derived
    // from each watch's own fonts (the fēnix 7S misses numMed by 3 px, the
    // Venu 3S keeps it by 1 px).
    (:test)
    function heroFontFollowsTheChargingWorstCase(logger as Logger) as Boolean {
        var med = [fenix7pro(), venu3s(), venu3(), venux1(), fenix7xpro(), fr255(), vivoactive5()] as Array<Geo.Display>;
        var mild = [vivoactive6(), venu445mm(), fenix7s(), fr255s(), fr265()] as Array<Geo.Display>;
        for (var i = 0; i < med.size(); i += 1) {
            var g = med[i] as Geo.Display;
            if (g.heroFont != Graphics.FONT_NUMBER_MEDIUM || g.unitFont != Graphics.FONT_MEDIUM) {
                logger.error("expected numberMedium on " + describe(g));
                return false;
            }
        }
        for (var i = 0; i < mild.size(); i += 1) {
            var g = mild[i] as Geo.Display;
            if (g.heroFont != Graphics.FONT_NUMBER_MILD || g.unitFont != Graphics.FONT_SMALL) {
                logger.error("expected numberMild on " + describe(g));
                return false;
            }
        }
        return true;
    }

    // Tokens on the other screens, derived by hand from the spec
    // (20-render.js geometry()): R - k * s radii, bottom-anchored lines
    // from the watch's own xtiny height, rows a quarter of the display.
    (:test)
    function tokensFollowTheScreen(logger as Logger) as Boolean {
        var v = venu3s();
        var x = venux1();
        var s7 = fenix7s();
        var s5 = fr255s();
        return _eq(logger, "venu3s titleTop", v.titleTop, 51)
            && _eq(logger, "venu3s statusTop", v.statusTop, 314)
            && _eq(logger, "venu3s chargingAgeTop", v.chargingAgeTop, 299)
            && _eq(logger, "venu3s chipH", v.chipH, 35)
            && _eq(logger, "venu3s rowH", v.rowH, 97)
            && _eq(logger, "venu3s heroBottom", v.heroBottom, 147)
            && _eq(logger, "venu3s ringR", v.ringR, 189)
            && _eq(logger, "venu3s glyphR", v.glyphR, 162)
            && _eq(logger, "venu3s dotsR", v.dotsR, 177)
            && _at(logger, "venu3s anchor start", v.anchor(:start), 335, 114)
            && _eq(logger, "venux1 titleTop", x.titleTop, 34)
            && _eq(logger, "venux1 statusTop", x.statusTop, 415)
            && _eq(logger, "venux1 chargingAgeTop", x.chargingAgeTop, 397)
            && _eq(logger, "venux1 rowH", x.rowH, 121)
            && _eq(logger, "venux1 heroBottom", x.heroBottom, 183)
            && _eq(logger, "venux1 corner", x.corner, 58)
            && _eq(logger, "fenix7s titleTop", s7.titleTop, 31)
            && _eq(logger, "fenix7s statusTop", s7.statusTop, 194)
            && _eq(logger, "fenix7s rowH", s7.rowH, 60)
            && _eq(logger, "fenix7s ringR", s7.ringR, 116)
            && _eq(logger, "fenix7s glyphR", s7.glyphR, 100)
            && _eq(logger, "fr255s titleTop", s5.titleTop, 29)
            && _eq(logger, "fr255s statusTop", s5.statusTop, 175)
            && _eq(logger, "fr255s rowH", s5.rowH, 54)
            && _eq(logger, "fr255s ringR", s5.ringR, 106)
            && _eq(logger, "fr255s glyphR", s5.glyphR, 91);
    }

    // Buttons: five on profile A, START and BACK elsewhere; on the X1 the
    // glyphs sit at the right edge, a quarter and three quarters down.
    (:test)
    function buttonsFollowTheProfile(logger as Logger) as Boolean {
        var b = venu3s();
        if (!b.hasButton(:start) || !b.hasButton(:back) || b.hasButton(:up) || b.hasButton(:down)
            || b.anchor(:up) != null || b.keyY(:down) != null) {
            logger.error("profile B has START and BACK only");
            return false;
        }
        if (!fenix7pro().hasButton(:up) || !fr255().hasButton(:down)) {
            logger.error("profile A has UP and DOWN");
            return false;
        }
        var x = venux1();
        return _eq(logger, "venux1 keyY start", x.keyY(:start), 121)
            && _eq(logger, "venux1 keyY back", x.keyY(:back), 364)
            && _at(logger, "venux1 anchor start", x.anchor(:start), 410, 121)
            && _at(logger, "venux1 anchor back", x.anchor(:back), 410, 364);
    }

    // DeviceSettings.inputButtons to profile: UP decides A, then MENU B.
    (:test)
    function inputFromTruthTable(logger as Logger) as Boolean {
        var five = System.BUTTON_INPUT_SELECT | System.BUTTON_INPUT_UP | System.BUTTON_INPUT_DOWN
            | System.BUTTON_INPUT_MENU | System.BUTTON_INPUT_CLOCK | System.BUTTON_INPUT_LAP;
        return _eq(logger, "five buttons", Geo.inputFrom(five), Geo.INPUT_A)
            && _eq(logger, "UP only", Geo.inputFrom(System.BUTTON_INPUT_UP), Geo.INPUT_A)
            && _eq(logger, "UP without MENU", Geo.inputFrom(System.BUTTON_INPUT_UP | System.BUTTON_INPUT_SELECT), Geo.INPUT_A)
            && _eq(logger, "MENU without UP", Geo.inputFrom(System.BUTTON_INPUT_SELECT | System.BUTTON_INPUT_MENU), Geo.INPUT_B)
            && _eq(logger, "SELECT only", Geo.inputFrom(System.BUTTON_INPUT_SELECT), Geo.INPUT_C)
            && _eq(logger, "nothing", Geo.inputFrom(0), Geo.INPUT_C);
    }

    // The indicator rect exists on profile C only; screens not in the table
    // get the 390 one scaled.
    (:test)
    function hintOnlyOnProfileC(logger as Logger) as Boolean {
        if (venu3s().hint != null || fenix7pro().hint != null) {
            logger.error("profiles A and B have no indicator");
            return false;
        }
        var v = vivoactive6().hint as Array<Number>;
        var x = venux1().hint as Array<Number>;
        var big = venu445mm().hint as Array<Number>;
        var other = Geo.hintFor(true, 416, 416, Geo.INPUT_C) as Array<Number>;
        return _eq(logger, "vivoactive6 hint x", v[0], 361) && _eq(logger, "vivoactive6 hint h", v[3], 91)
            && _eq(logger, "venu445mm hint y", big[1], 176)
            && _eq(logger, "venux1 hint x", x[0], 422) && _eq(logger, "venux1 hint y", x[1], 190)
            && _eq(logger, "416 hint x", other[0], 385) && _eq(logger, "416 hint w", other[2], 23);
    }

    // The keep-out narrows only the right side, only inside the band, and
    // only while the indicator shows.
    (:test)
    function keepOutNarrowsOnlyTheRightInsideTheBand(logger as Logger) as Boolean {
        var g = vivoactive6();
        var inBand = g.span(180, 210, 8);
        var above = g.span(100, 130, 8);
        g.keepOut = true;
        var inBandOut = g.span(180, 210, 8);
        var aboveOut = g.span(100, 130, 8);
        if (inBandOut[0] != inBand[0]) {
            logger.error("the left bound must not move");
            return false;
        }
        if (!_eq(logger, "right bound in the band", inBandOut[1], 361 - 12)) {
            return false;
        }
        if (aboveOut[0] != above[0] || aboveOut[1] != above[1]) {
            logger.error("a box above the band must keep its width");
            return false;
        }
        if (!_eq(logger, "centred width in the band", g.usable(180, 210, 8), 2 * (361 - 12 - 195))) {
            return false;
        }
        g.keepOut = false;
        var back = g.span(180, 210, 8);
        if (back[1] != inBand[1]) {
            logger.error("keep-out off must restore the right bound");
            return false;
        }
        var f = fenix7pro();
        f.keepOut = true;
        if (f.usable(120, 140, 8) != fenix7pro().usable(120, 140, 8)) {
            logger.error("without an indicator the keep-out changes nothing");
            return false;
        }
        return true;
    }

    // The X1 outline: full width between the corners, the corner circle
    // near the top and bottom, nothing outside.
    (:test)
    function rectangleOutline(logger as Logger) as Boolean {
        var x = venux1();
        return _eq(logger, "middle", x.halfChord(0), 224)
            && _eq(logger, "just inside the corners", x.halfChord(243 - 58), 224)
            && _eq(logger, "10 px from the top", x.halfChord(233), 198)
            && _eq(logger, "the edge", x.halfChord(243), 0)
            && _eq(logger, "usable middle", x.usable(230, 256, 8), 2 * 224 - 2 * 14)
            && _eq(logger, "usable at the title, in the corner zone", x.usable(34, 81, 8), 2 * 218 - 2 * 14);
    }

    // The real device: logs every token, and when this watch matches a
    // fixture (screen, profile, touch and fonts) every token must equal it.
    // On the fēnix 7 Pro that is the pin: today's layout, live.
    (:test)
    function liveTokensMatchTheFixture(logger as Logger) as Boolean {
        var g = Geo.current();
        System.println("TOKENS " + System.getDeviceSettings().partNumber + " " + describe(g));
        var all = all();
        var live = _key(g);
        for (var i = 0; i < all.size(); i += 1) {
            var f = all[i] as Geo.Display;
            if (_key(f).equals(live) && !describe(g).equals(describe(f))) {
                logger.error("live " + describe(g) + " differs from its fixture " + describe(f));
                return false;
            }
        }
        if (g.w == 260 && g.h == 260 && g.round && g.input == Geo.INPUT_A && g.fonts.xtinyH == 19 && g.fonts.numMedH == 74
            && !describe(g).equals(describe(fenix7pro()))) {
            logger.error("a 260 five-button watch with the fēnix 7 Pro fonts must have its tokens");
            return false;
        }
        return true;
    }

    // What identifies a fixture: everything Geo.make() takes.
    function _key(g as Geo.Display) as String {
        var f = g.fonts;
        return g.w + "x" + g.h + " " + g.round + " " + g.input + " " + g.touch + " " + f.xtinyH + "/" + f.tinyH + "/"
            + f.smallH + "/" + f.mediumH + "/" + f.numMildH + "/" + f.numMedH;
    }

}
