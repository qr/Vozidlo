import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The bezel zone (r >= 108): hint arcs and glyphs next to the buttons, the
// SoC ring, page dots and the Find my car pointer (B4: no text hints at the
// bottom; the bezel holds only arcs, dots and glyphs).
//
// Angles are canvas degrees throughout (0 = 3 o'clock, clockwise, as in the
// PoC); ciqDegrees() is the one conversion to Dc.drawArc's convention, so no
// caller mixes the two. Centre and radii assume the 260x260 round family all
// six targets share (decisions.md "One device family").
module Bezel {

    const C = 130;

    // Button positions on the fēnix 7 Pro / 8 / 9 / fr955 bezel, canvas degrees.
    const BTN_START = -30;
    const BTN_BACK = 30;
    const BTN_DOWN = 150;
    const BTN_UP = 180;

    const RING_R = 126;
    const RING_PEN = 4;
    const HINT_HALF_DEG = 10;
    const GLYPH_R = 108;
    const GLYPH_ICON_R = 6;
    const DOTS_R = 118;
    const DOTS_STEP_DEG = 7.5;

    // ------------------------------------------------------------ pure

    // Dc.drawArc counts degrees counter-clockwise from 3 o'clock; the design
    // (and polar()) counts clockwise. Mixing the two mirrors every arc
    // across the horizontal axis, so this is the only place they meet.
    function ciqDegrees(canvasDeg as Number) as Number {
        var d = (360 - canvasDeg) % 360;
        return d < 0 ? d + 360 : d;
    }

    // Screen point at radius r and canvas angle, rounded to pixels.
    function polar(r as Numeric, canvasDeg as Numeric) as [Number, Number] {
        var rad = Math.toRadians(canvasDeg);
        var x = Math.round(C + Math.cos(rad) * r).toNumber();
        var y = Math.round(C + Math.sin(rad) * r).toNumber();
        return [x, y];
    }

    // ------------------------------------------------------------ drawing

    // Personality-style hint arc next to a button (B4): a 4 px band at r 126,
    // ±10° around it. Kinds: :dark (white), :accent, :positive, :destructive.
    function hintArc(dc as Dc, btn as Number, kind as Symbol) as Void {
        var color = Theme.TEXT_1;
        if (kind == :accent) {
            color = Theme.ACCENT;
        } else if (kind == :positive) {
            color = Theme.POSITIVE;
        } else if (kind == :destructive) {
            color = Theme.DESTRUCTIVE;
        }
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(RING_PEN);
        _arc(dc, RING_R, btn - HINT_HALF_DEG, btn + HINT_HALF_DEG);
        dc.setPenWidth(1);
    }

    // Small icon just inside the bezel next to a button, replacing the old
    // bottom text hints (A3 superseded); optional hint arc when arcKind is set.
    function glyph(dc as Dc, btn as Number, icon as Symbol, color as Number, arcKind as Symbol?) as Void {
        var p = polar(GLYPH_R, btn);
        NightIcons.draw(dc, icon, p[0], p[1], GLYPH_ICON_R, Theme.c(color));
        if (arcKind != null) {
            hintArc(dc, btn, arcKind);
        }
    }

    // SoC ring (C1b, C3): track in RULE, fill from 12 o'clock clockwise, and
    // an optional tick at the charge limit. tickFrac null means no limit known.
    function ring(dc as Dc, frac as Numeric, fill as Number, tickFrac as Numeric?) as Void {
        dc.setPenWidth(RING_PEN);
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(C, C, RING_R);
        if (frac >= 1) {
            dc.setColor(Theme.c(fill), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(C, C, RING_R);
        } else if (frac > 0) {
            // drawArc with equal ends draws a full circle; 1° minimum avoids that.
            var sweep = (360 * frac).toNumber();
            if (sweep < 1) {
                sweep = 1;
            }
            dc.setColor(Theme.c(fill), Graphics.COLOR_TRANSPARENT);
            _arc(dc, RING_R, -90, -90 + sweep);
        }
        if (tickFrac != null) {
            var a = -90 + 360 * tickFrac;
            var p0 = polar(RING_R - 7, a);
            var p1 = polar(RING_R + 3, a);
            dc.setPenWidth(2);
            dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }
        dc.setPenWidth(1);
    }

    // Own page indicator (D7) on the left, centred on 9 o'clock: current dot
    // larger and in the accent, so size alone marks it under monochrome.
    function pageDots(dc as Dc, idx as Number, count as Number) as Void {
        for (var i = 0; i < count; i += 1) {
            var a = 180 + ((count - 1) / 2.0 - i) * DOTS_STEP_DEG;
            var p = polar(DOTS_R, a);
            if (i == idx) {
                dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], 4);
            } else {
                dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], 3);
            }
        }
    }

    // Find my car bearing (C5): accent wedge on r 117..129, apex outward.
    // angleRad is clockwise from screen-up, as LocationMath.arrowAngleRadians
    // returns it. Outline only (filled false) while there is no compass
    // heading, so the user can tell north-up from heading-up.
    function pointer(dc as Dc, angleRad as Numeric, filled as Boolean) as Void {
        var a = Math.toDegrees(angleRad) - 90;
        var tip = polar(129, a);
        var l = polar(117, a - 7);
        var r = polar(117, a + 7);
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        if (filled) {
            dc.fillPolygon([tip, l, r] as Array<Graphics.Point2D>);
            return;
        }
        dc.setPenWidth(2);
        dc.drawLine(tip[0], tip[1], l[0], l[1]);
        dc.drawLine(l[0], l[1], r[0], r[1]);
        dc.drawLine(r[0], r[1], tip[0], tip[1]);
        dc.setPenWidth(1);
    }

    // Arc from canvas angle `from` clockwise to `to`.
    function _arc(dc as Dc, r as Number, from as Number, to as Number) as Void {
        dc.drawArc(C, C, r, Graphics.ARC_CLOCKWISE, ciqDegrees(from), ciqDegrees(to));
    }

}
