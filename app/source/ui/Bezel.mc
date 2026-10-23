import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The bezel zone (r >= glyphR): hint arcs and glyphs next to the buttons,
// the SoC ring, page dots and the Find my car pointer and track (B4: no text
// hints at the bottom; the bezel holds only arcs, dots and glyphs).
//
// Angles are canvas degrees throughout (0 = 3 o'clock, clockwise, as in the
// PoC); ciqDegrees() is the one conversion to Dc.drawArc's convention, so no
// caller mixes the two. Centre, radii and button positions come from the
// screen (Geo.current(); decisions.md "Layouts follow the screen, measured
// from the Dc"): R - k * s on a round face, the display frame on the Venu X1
// rectangle, glyphs only at buttons the watch has.
module Bezel {

    // Deprecated: the centre of the 260 face. Use Geo.current().cx / .cy;
    // kept until every caller has moved (LocationView).
    const C = 130;

    // Deprecated: button angles for glyph() / hintArc(). New code passes a
    // position (:start, :back, :up, :down) to glyphAt() / hintArcAt().
    // Same values as Geo.ANGLE_*.
    const BTN_START = -30;
    const BTN_BACK = 30;
    const BTN_DOWN = 150;
    const BTN_UP = 180;

    const HINT_HALF_DEG = 10;
    const DOTS_STEP_DEG = 7.5;

    // ------------------------------------------------------------ pure

    // Dc.drawArc counts degrees counter-clockwise from 3 o'clock; the design
    // (and polarAt()) counts clockwise. Mixing the two mirrors every arc
    // across the horizontal axis, so this is the only place they meet.
    function ciqDegrees(canvasDeg as Number) as Number {
        var d = (360 - canvasDeg) % 360;
        return d < 0 ? d + 360 : d;
    }

    // Screen point at radius r and canvas angle around (cx, cy), rounded
    // to pixels.
    function polarAt(cx as Numeric, cy as Numeric, r as Numeric, canvasDeg as Numeric) as [Number, Number] {
        var rad = Math.toRadians(canvasDeg);
        var x = Math.round(cx + Math.cos(rad) * r).toNumber();
        var y = Math.round(cy + Math.sin(rad) * r).toNumber();
        return [x, y];
    }

    // polarAt() around the centre of this screen.
    function polar(r as Numeric, canvasDeg as Numeric) as [Number, Number] {
        var g = Geo.current();
        return polarAt(g.cx, g.cy, r, canvasDeg);
    }

    // Position for one of the deprecated BTN_* angles.
    function posOf(btn as Number) as Symbol {
        if (btn == BTN_BACK) {
            return :back;
        }
        if (btn == BTN_DOWN) {
            return :down;
        }
        if (btn == BTN_UP) {
            return :up;
        }
        return :start;
    }

    // The rectangle's ring/track frame (Venu X1): the display outline inset
    // px(4), corners g.corner - px(4), walked clockwise from top centre as
    // nine pieces. Each is [0, x, y, dx, dy, length] for a line or
    // [1, cx, cy, startDeg, r, length] for a quarter arc.
    function _framePieces(g as Geo.Display) as Array<Array<Float>> {
        var ins = g.px(4);
        var r = (g.corner - ins).toFloat();
        if (r < 0) {
            r = 0.0;
        }
        var x0 = ins.toFloat();
        var y0 = ins.toFloat();
        var x1 = (g.w - ins).toFloat();
        var y1 = (g.h - ins).toFloat();
        var cx = g.cx.toFloat();
        var a = Math.PI.toFloat() * r / 2;
        var side = y1 - y0 - 2 * r;
        var across = x1 - x0 - 2 * r;
        return [
            [0.0, cx, y0, 1.0, 0.0, x1 - r - cx],
            [1.0, x1 - r, y0 + r, -90.0, r, a],
            [0.0, x1, y0 + r, 0.0, 1.0, side],
            [1.0, x1 - r, y1 - r, 0.0, r, a],
            [0.0, x1 - r, y1, -1.0, 0.0, across],
            [1.0, x0 + r, y1 - r, 90.0, r, a],
            [0.0, x0, y1 - r, 0.0, -1.0, side],
            [1.0, x0 + r, y0 + r, 180.0, r, a],
            [0.0, x0 + r, y0, 1.0, 0.0, cx - x0 - r]
        ] as Array<Array<Float>>;
    }

    function _frameLength(pieces as Array<Array<Float>>) as Float {
        var total = 0.0;
        for (var i = 0; i < pieces.size(); i += 1) {
            total += (pieces[i] as Array<Float>)[5] as Float;
        }
        return total;
    }

    // Point u px into one frame piece.
    function _pieceAt(p as Array<Float>, u as Float) as [Float, Float] {
        if (p[0] == 0.0) {
            return [(p[1] as Float) + (p[3] as Float) * u, (p[2] as Float) + (p[4] as Float) * u];
        }
        var r = p[4] as Float;
        var rad = Math.toRadians((p[3] as Float) + (r > 0 ? Math.toDegrees(u / r) : 0.0)).toFloat();
        return [(p[1] as Float) + r * Math.cos(rad).toFloat(), (p[2] as Float) + r * Math.sin(rad).toFloat()];
    }

    // Point at fraction t (0..1, wrapping) of the rectangle frame, clockwise
    // from top centre: where the ring fill ends and the limit tick sits.
    function framePoint(g as Geo.Display, t as Numeric) as [Float, Float] {
        var pieces = _framePieces(g);
        var total = _frameLength(pieces);
        var f = t.toFloat() - Math.floor(t.toFloat()).toFloat();
        var at = f * total;
        for (var i = 0; i < pieces.size(); i += 1) {
            var p = pieces[i] as Array<Float>;
            var len = p[5] as Float;
            if (at <= len || i == pieces.size() - 1) {
                return _pieceAt(p, at < len ? at : len);
            }
            at -= len;
        }
        return [g.cx.toFloat(), g.px(4).toFloat()];
    }

    // Where a ray from the centre at canvas angle `deg` meets the rectangle
    // frame: the Find my car pointer's base point on the Venu X1.
    function frameHit(g as Geo.Display, deg as Numeric) as [Float, Float] {
        var ins = g.px(4);
        var r = (g.corner - ins).toFloat();
        if (r < 0) {
            r = 0.0;
        }
        var x0 = ins.toFloat();
        var y0 = ins.toFloat();
        var x1 = (g.w - ins).toFloat();
        var y1 = (g.h - ins).toFloat();
        var cx = g.cx.toFloat();
        var cy = g.cy.toFloat();
        var rad = Math.toRadians(deg);
        var ux = Math.cos(rad).toFloat();
        var uy = Math.sin(rad).toFloat();
        var t = 1.0e9;
        if (ux > 1.0e-6) {
            t = (x1 - cx) / ux;
        } else if (ux < -1.0e-6) {
            t = (x0 - cx) / ux;
        }
        var ty = 1.0e9;
        if (uy > 1.0e-6) {
            ty = (y1 - cy) / uy;
        } else if (uy < -1.0e-6) {
            ty = (y0 - cy) / uy;
        }
        if (ty < t) {
            t = ty;
        }
        var x = cx + ux * t;
        var y = cy + uy * t;
        if (r <= 0) {
            return [x, y];
        }
        // In a corner zone the frame is the corner circle: the ray leaves
        // that circle where it crosses the frame (the larger root).
        var kx = x > x1 - r ? x1 - r : (x < x0 + r ? x0 + r : null);
        var ky = y > y1 - r ? y1 - r : (y < y0 + r ? y0 + r : null);
        if (kx == null || ky == null) {
            return [x, y];
        }
        var fx = cx - (kx as Float);
        var fy = cy - (ky as Float);
        var b = fx * ux + fy * uy;
        var disc = b * b - (fx * fx + fy * fy - r * r);
        if (disc < 0) {
            return [x, y];
        }
        var tc = -b + Math.sqrt(disc).toFloat();
        return [cx + ux * tc, cy + uy * tc];
    }

    // ------------------------------------------------------------ drawing

    // Personality-style hint at a button (B4). Round: a ringPen band on the
    // ring radius, ±10° around the button. Rectangle: a short bar on the
    // right edge next to the key. Kinds: :dark (white), :accent, :positive,
    // :destructive. Nothing on a watch without that button.
    function hintArcAt(dc as Dc, pos as Symbol, kind as Symbol) as Void {
        var g = Geo.current();
        if (!g.hasButton(pos)) {
            return;
        }
        var color = Theme.TEXT_1;
        if (kind == :accent) {
            color = Theme.ACCENT;
        } else if (kind == :positive) {
            color = Theme.POSITIVE;
        } else if (kind == :destructive) {
            color = Theme.DESTRUCTIVE;
        }
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        if (g.round) {
            var a = Geo.buttonAngle(pos);
            dc.setPenWidth(g.ringPen);
            _arc(dc, g.cx, g.cy, g.ringR, a - HINT_HALF_DEG, a + HINT_HALF_DEG);
            dc.setPenWidth(1);
            return;
        }
        var y = g.keyY(pos) as Number;
        dc.fillRoundedRectangle(g.w - g.px(5), y - g.px(22), g.px(3), g.px(44), g.px(3) / 2);
    }

    // Small icon just inside the bezel next to a button, replacing the old
    // bottom text hints (A3 superseded); optional hint arc when arcKind is
    // set. Nothing on a watch without that button: the screen then needs a
    // touch route of its own.
    function glyphAt(dc as Dc, pos as Symbol, icon as Symbol, color as Number, arcKind as Symbol?) as Void {
        var g = Geo.current();
        var p = g.anchor(pos);
        if (p == null) {
            return;
        }
        NightIcons.draw(dc, icon, p[0], p[1], g.glyphIconR, Theme.c(color));
        if (arcKind != null) {
            hintArcAt(dc, pos, arcKind);
        }
    }

    // Deprecated: glyphAt() with a BTN_* angle.
    function glyph(dc as Dc, btn as Number, icon as Symbol, color as Number, arcKind as Symbol?) as Void {
        glyphAt(dc, posOf(btn), icon, color, arcKind);
    }

    // Deprecated: hintArcAt() with a BTN_* angle.
    function hintArc(dc as Dc, btn as Number, kind as Symbol) as Void {
        hintArcAt(dc, posOf(btn), kind);
    }

    // The MENU glyph, routed by input profile: at UP on five buttons (A,
    // hold UP), grey at BACK where MENU is hold BACK (B), and nothing on
    // watches without MENU (C), where the system draws its action menu
    // indicator (Input.enableIndicator). No hint arc on either.
    function menuGlyph(dc as Dc, color as Number) as Void {
        var input = Geo.current().input;
        if (input == Geo.INPUT_A) {
            glyphAt(dc, :up, :menu, color, null);
        } else if (input == Geo.INPUT_B) {
            glyphAt(dc, :back, :menu, Theme.TEXT_2, null);
        }
    }

    // SoC ring (C1b, C3): track in RULE, fill from 12 o'clock clockwise, and
    // an optional tick at the charge limit. tickFrac null means no limit
    // known. On the rectangle the ring is the display frame, inset px(4).
    function ring(dc as Dc, frac as Numeric, fill as Number, tickFrac as Numeric?) as Void {
        var g = Geo.current();
        dc.setPenWidth(g.ringPen);
        if (!g.round) {
            _frameRing(dc, g, frac, fill, tickFrac);
            return;
        }
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(g.cx, g.cy, g.ringR);
        if (frac >= 1) {
            dc.setColor(Theme.c(fill), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(g.cx, g.cy, g.ringR);
        } else if (frac > 0) {
            // drawArc with equal ends draws a full circle; 1° minimum avoids that.
            var sweep = (360 * frac).toNumber();
            if (sweep < 1) {
                sweep = 1;
            }
            dc.setColor(Theme.c(fill), Graphics.COLOR_TRANSPARENT);
            _arc(dc, g.cx, g.cy, g.ringR, -90, -90 + sweep);
        }
        if (tickFrac != null) {
            var a = -90 + 360 * tickFrac;
            var p0 = polarAt(g.cx, g.cy, g.ringR - g.px(7), a);
            var p1 = polarAt(g.cx, g.cy, g.ringR + g.px(3), a);
            dc.setPenWidth(g.px(2));
            dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }
        dc.setPenWidth(1);
    }

    function _frameRing(dc as Dc, g as Geo.Display, frac as Numeric, fill as Number, tickFrac as Numeric?) as Void {
        var pieces = _framePieces(g);
        var total = _frameLength(pieces);
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        _framePart(dc, pieces, 0.0, total);
        if (frac > 0) {
            var f = frac >= 1 ? 1.0 : frac.toFloat();
            dc.setColor(Theme.c(fill), Graphics.COLOR_TRANSPARENT);
            _framePart(dc, pieces, 0.0, f * total);
        }
        if (tickFrac != null) {
            // Normal from the travel direction: outward is left of a
            // clockwise walk on a y-down screen.
            var p = framePoint(g, tickFrac);
            var q = framePoint(g, tickFrac + 0.002);
            var dx = q[0] - p[0];
            var dy = q[1] - p[1];
            var len = Math.sqrt(dx * dx + dy * dy).toFloat();
            if (len > 0) {
                var nx = dy / len;
                var ny = -dx / len;
                var inner = g.px(7);
                var outer = g.px(3);
                dc.setPenWidth(g.px(2));
                dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
                dc.drawLine(p[0] - nx * inner, p[1] - ny * inner, p[0] + nx * outer, p[1] + ny * outer);
            }
        }
        dc.setPenWidth(1);
    }

    // Strokes the frame from length `from` to `to` (px along the frame) in
    // the current colour and pen.
    function _framePart(dc as Dc, pieces as Array<Array<Float>>, from as Float, to as Float) as Void {
        var start = 0.0;
        for (var i = 0; i < pieces.size(); i += 1) {
            var p = pieces[i] as Array<Float>;
            var len = p[5] as Float;
            var a = from > start ? from - start : 0.0;
            var b = to < start + len ? to - start : len;
            start += len;
            if (b <= a) {
                continue;
            }
            if (p[0] == 0.0) {
                var pa = _pieceAt(p, a);
                var pb = _pieceAt(p, b);
                dc.drawLine(pa[0], pa[1], pb[0], pb[1]);
                continue;
            }
            var r = p[4] as Float;
            if (r <= 0) {
                continue;
            }
            var d0 = Math.round((p[3] as Float) + Math.toDegrees(a / r)).toNumber();
            var d1 = Math.round((p[3] as Float) + Math.toDegrees(b / r)).toNumber();
            if (d1 > d0) {
                _arc(dc, Math.round(p[1] as Float).toNumber(), Math.round(p[2] as Float).toNumber(),
                    Math.round(r).toNumber(), d0, d1);
            }
        }
    }

    // Find my car track (C5): the thin circle the text sits inside, or the
    // display frame on the rectangle.
    function track(dc as Dc) as Void {
        var g = Geo.current();
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        if (g.round) {
            dc.setPenWidth(g.px(2));
            dc.drawCircle(g.cx, g.cy, g.trackR);
        } else {
            dc.setPenWidth(g.px(3));
            var pieces = _framePieces(g);
            _framePart(dc, pieces, 0.0, _frameLength(pieces));
        }
        dc.setPenWidth(1);
    }

    // Own page indicator (D7) on the left, centred on 9 o'clock: current dot
    // larger and in the accent, so size alone marks it under monochrome.
    function pageDots(dc as Dc, idx as Number, count as Number) as Void {
        var g = Geo.current();
        for (var i = 0; i < count; i += 1) {
            var a = 180 + ((count - 1) / 2.0 - i) * DOTS_STEP_DEG;
            var p = polarAt(g.cx, g.cy, g.dotsR, a);
            if (i == idx) {
                dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], g.px(4));
            } else {
                dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], g.px(3));
            }
        }
    }

    // Find my car bearing (C5): accent wedge from R - px(13) out to
    // R - px(1) (r 117..129 on the fēnix), apex outward; on the rectangle a
    // wedge of the same size on the frame. angleRad is clockwise from
    // screen-up, as LocationMath.arrowAngleRadians returns it. Outline only
    // (filled false) while there is no compass heading, so the user can
    // tell north-up from heading-up.
    function pointer(dc as Dc, angleRad as Numeric, filled as Boolean) as Void {
        var g = Geo.current();
        var a = Math.toDegrees(angleRad) - 90;
        var pts;
        if (g.round) {
            pts = [polarAt(g.cx, g.cy, g.R - g.px(1), a),
                   polarAt(g.cx, g.cy, g.R - g.px(13), a - 7),
                   polarAt(g.cx, g.cy, g.R - g.px(13), a + 7)];
        } else {
            var hit = frameHit(g, a);
            var rad = Math.toRadians(a);
            var ux = Math.cos(rad).toFloat();
            var uy = Math.sin(rad).toFloat();
            var tip = g.px(3);
            var back = g.px(15);
            var half = g.px(7);
            var bx = hit[0] - ux * back;
            var by = hit[1] - uy * back;
            pts = [[Math.round(hit[0] + ux * tip).toNumber(), Math.round(hit[1] + uy * tip).toNumber()],
                   [Math.round(bx - uy * half).toNumber(), Math.round(by + ux * half).toNumber()],
                   [Math.round(bx + uy * half).toNumber(), Math.round(by - ux * half).toNumber()]];
        }
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        if (filled) {
            dc.fillPolygon(pts as Array<Graphics.Point2D>);
            return;
        }
        var t = pts[0] as [Number, Number];
        var l = pts[1] as [Number, Number];
        var r = pts[2] as [Number, Number];
        dc.setPenWidth(g.px(2));
        dc.drawLine(t[0], t[1], l[0], l[1]);
        dc.drawLine(l[0], l[1], r[0], r[1]);
        dc.drawLine(r[0], r[1], t[0], t[1]);
        dc.setPenWidth(1);
    }

    // Arc around (cx, cy) from canvas angle `from` clockwise to `to`.
    function _arc(dc as Dc, cx as Number, cy as Number, r as Number, from as Number, to as Number) as Void {
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, ciqDegrees(from), ciqDegrees(to));
    }

}
