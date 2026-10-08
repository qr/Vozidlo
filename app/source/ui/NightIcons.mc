import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Solid action icons for the Night Panel (B4: one family, solid silhouettes
// with cut-outs; thin round-cap outlines fade on the MIP panel). Shapes match
// NIcons in docs/design/vozidlo-poc.html. State icons (:locked, :charging,
// ...) pass through to StateIcons so there is one drawing per state.
//
// App scope only: the glance draws StateIcons directly, which keeps these
// shapes out of the 64 KB glance arena.
module NightIcons {

    // Draws `name` centred on cx/cy with half-size r. Cut-outs are drawn in
    // black: every Night Panel surface an icon sits on is black or a filled
    // pill whose icon is black anyway.
    function draw(dc as Dc, name as Symbol, cx as Number, cy as Number, r as Number, color as Number) as Void {
        if (_isStateIcon(name)) {
            StateIcons.draw(dc, name, cx, cy, r, color);
            return;
        }
        if (name == :bolt) {
            StateIcons.draw(dc, StateIcons.CHARGING, cx, cy, r, color);
            return;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pen = r / 3;
        dc.setPenWidth(pen < 2 ? 2 : pen);
        if (name == :battery) {
            dc.drawRoundedRectangle(_t(cx - r), _t(cy - r * 0.55), _t(r * 1.8), _t(r * 1.1), 2);
            dc.fillRectangle(_t(cx + r * 0.8), _t(cy - r * 0.25), _t(r * 0.25), _t(r * 0.5));
            dc.fillRectangle(_t(cx - r * 0.7), _t(cy - r * 0.3), _t(r * 1.2), _t(r * 0.6));
        } else if (name == :range) {
            dc.fillPolygon([
                _p(cx - r, cy), _p(cx + r * 0.2, cy - r * 0.8), _p(cx + r * 0.2, cy - r * 0.3),
                _p(cx + r, cy - r * 0.3), _p(cx + r, cy + r * 0.3), _p(cx + r * 0.2, cy + r * 0.3),
                _p(cx + r * 0.2, cy + r * 0.8)
            ] as Array<Graphics.Point2D>);
        } else if (name == :fan) {
            for (var i = 0; i < 3; i += 1) {
                var a = i * 2.094;
                dc.fillCircle(_t(cx + Math.cos(a) * r * 0.5), _t(cy + Math.sin(a) * r * 0.5), _t(r * 0.45));
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, _min1(r * 0.18));
        } else if (name == :pin) {
            dc.fillCircle(cx, _t(cy - r * 0.25), _t(r * 0.65));
            dc.fillPolygon([
                _p(cx - r * 0.55, cy - r * 0.05), _p(cx + r * 0.55, cy - r * 0.05), _p(cx, cy + r)
            ] as Array<Graphics.Point2D>);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _t(cy - r * 0.25), _min1(r * 0.25));
        } else if (name == :list) {
            for (var i = -1; i <= 1; i += 1) {
                dc.fillRectangle(_t(cx - r), _t(cy + i * r * 0.65 - r * 0.15), 2 * r, _min2(r * 0.3));
            }
        } else if (name == :gear) {
            dc.fillCircle(cx, cy, _t(r * 0.7));
            for (var i = 0; i < 6; i += 1) {
                var a = i * Math.PI / 3;
                dc.fillCircle(_t(cx + Math.cos(a) * r * 0.8), _t(cy + Math.sin(a) * r * 0.8), _min1(r * 0.25));
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, _min1(r * 0.3));
        } else if (name == :stop) {
            dc.fillRoundedRectangle(_t(cx - r * 0.75), _t(cy - r * 0.75), _t(r * 1.5), _t(r * 1.5), 2);
        } else if (name == :refresh) {
            // Canvas -60..240 clockwise (gap at the top), in CIQ degrees.
            dc.drawArc(cx, cy, _t(r * 0.75), Graphics.ARC_CLOCKWISE, 60, 120);
            dc.fillPolygon([
                _p(cx + r * 0.2, cy - r * 1.05), _p(cx + r * 0.95, cy - r * 0.65), _p(cx + r * 0.2, cy - r * 0.2)
            ] as Array<Graphics.Point2D>);
        } else if (name == :check) {
            dc.setPenWidth(_min2(r / 2.5));
            dc.drawLine(_t(cx - r * 0.8), cy, _t(cx - r * 0.2), _t(cy + r * 0.6));
            dc.drawLine(_t(cx - r * 0.2), _t(cy + r * 0.6), _t(cx + r * 0.85), _t(cy - r * 0.6));
        } else if (name == :cross) {
            dc.setPenWidth(_min2(r / 2.5));
            dc.drawLine(_t(cx - r * 0.7), _t(cy - r * 0.7), _t(cx + r * 0.7), _t(cy + r * 0.7));
            dc.drawLine(_t(cx + r * 0.7), _t(cy - r * 0.7), _t(cx - r * 0.7), _t(cy + r * 0.7));
        } else if (name == :bang) {
            dc.fillRectangle(_t(cx - r * 0.17), cy - r, _min2(r * 0.34), _t(r * 1.25));
            dc.fillRectangle(_t(cx - r * 0.17), _t(cy + r * 0.55), _min2(r * 0.34), _min2(r * 0.38));
        } else if (name == :plus) {
            dc.fillRectangle(cx - r, _t(cy - r * 0.18), 2 * r, _min2(r * 0.36));
            dc.fillRectangle(_t(cx - r * 0.18), cy - r, _min2(r * 0.36), 2 * r);
        } else if (name == :minus) {
            dc.fillRectangle(cx - r, _t(cy - r * 0.18), 2 * r, _min2(r * 0.36));
        } else if (name == :menu) {
            for (var i = -1; i <= 1; i += 1) {
                dc.fillCircle(cx, _t(cy + i * r * 0.7), _min1(r * 0.22));
            }
        } else if (name == :map) {
            dc.fillPolygon([
                _p(cx - r, cy - r * 0.7), _p(cx - r * 0.33, cy - r), _p(cx + r * 0.33, cy - r * 0.7),
                _p(cx + r, cy - r), _p(cx + r, cy + r * 0.7), _p(cx + r * 0.33, cy + r),
                _p(cx - r * 0.33, cy + r * 0.7), _p(cx - r, cy + r)
            ] as Array<Graphics.Point2D>);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(_t(cx - r * 0.33), cy - r, _t(cx - r * 0.33), _t(cy + r * 0.7));
            dc.drawLine(_t(cx + r * 0.33), _t(cy - r * 0.7), _t(cx + r * 0.33), cy + r);
        } else if (name == :thermo) {
            dc.fillRoundedRectangle(_t(cx - r * 0.22), cy - r, _t(r * 0.44), _t(r * 1.3), _t(r * 0.22));
            dc.fillCircle(cx, _t(cy + r * 0.55), _t(r * 0.45));
        } else {
            StateIcons.draw(dc, StateIcons.UNKNOWN, cx, cy, r, color);
        }
        dc.setPenWidth(1);
    }

    function _isStateIcon(name as Symbol) as Boolean {
        return name == StateIcons.LOCKED || name == StateIcons.UNLOCKED || name == StateIcons.OPEN
            || name == StateIcons.CHARGING || name == StateIcons.PLUGGED_IN
            || name == StateIcons.CLIMATE_ACTIVE || name == StateIcons.UNKNOWN;
    }

    function _t(v as Numeric) as Number {
        return v.toNumber();
    }

    function _min1(v as Numeric) as Number {
        var n = v.toNumber();
        return n < 1 ? 1 : n;
    }

    function _min2(v as Numeric) as Number {
        var n = v.toNumber();
        return n < 2 ? 2 : n;
    }

    function _p(x as Numeric, y as Numeric) as Graphics.Point2D {
        return [x.toNumber(), y.toNumber()] as Graphics.Point2D;
    }

}
