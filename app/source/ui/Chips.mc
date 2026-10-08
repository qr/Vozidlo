import Toybox.Graphics;
import Toybox.Lang;

// Status chips (B2, B4): a pill with an icon and one word, at most three per
// row. Kinds carry meaning by fill, and warn/error always carry "!" so the
// meaning survives the monochrome test (B1.2, B1.5).
module Chips {

    // One chip. kind: :outline (normal state), :warn (amber, insecure or
    // stale), :error (red), :accent (charging), :white (neutral emphasis).
    class Chip {
        var text as String;
        var icon as Symbol?;
        var kind as Symbol;

        function initialize(text as String, icon as Symbol?, kind as Symbol) {
            self.text = text;
            self.icon = icon;
            self.kind = kind;
        }
    }

    const PAD = 8;
    const ICON_W = 14;

    // ------------------------------------------------------------ pure

    // Chip width for a measured text width: 8 px padding both sides, 14 for
    // the icon (r 6 plus a gap). Pure so layouts can be checked in tests.
    function width(textW as Number, hasIcon as Boolean) as Number {
        return 2 * PAD + (hasIcon ? ICON_W : 0) + textW;
    }

    // Width of a centred row, for the "usable >= row" check (C8 step 3).
    function rowWidth(widths as Array<Number>, gap as Number) as Number {
        if (widths.size() == 0) {
            return 0;
        }
        var total = gap * (widths.size() - 1);
        for (var i = 0; i < widths.size(); i += 1) {
            total += widths[i] as Number;
        }
        return total;
    }

    // Icon actually drawn: warn and error always show "!" (B3 "always with
    // icon or !"), whatever icon the chip asked for.
    function iconFor(chip as Chip) as Symbol? {
        if (chip.kind == :warn || chip.kind == :error) {
            return :bang;
        }
        return chip.icon;
    }

    // Lock chip (US-059): secure is a quiet outline, anything insecure amber.
    // null when nothing is cached, so the hero shows no chip rather than "—".
    function forLock(raw as String?) as Chip? {
        if (raw == null) {
            return null;
        }
        if (Labels.isInsecureLock(raw)) {
            return new Chip(Labels.lock(raw), null, :warn);
        }
        return new Chip(Labels.lock(raw), StateIcons.forLockStatus(raw), :outline);
    }

    // Charging chip (US-022, US-023): accent while charging, outline when
    // plugged in, amber "Plug in" when the car wants a cable (PoC "! Plug in").
    // null for states that need no chip (no data, discharging, unknown).
    function forCharging(raw as String?) as Chip? {
        if (raw == null) {
            return null;
        }
        if (raw.equals("CONNECT_CABLE")) {
            return new Chip(Labels.charging(raw), null, :warn);
        }
        var icon = StateIcons.forChargingStatus(raw);
        if (icon == null) {
            return null;
        }
        if (icon == StateIcons.CHARGING) {
            return new Chip(Labels.charging(raw), icon, :accent);
        }
        return new Chip(Labels.charging(raw), icon, :outline);
    }

    // Climate chip: only while the climate runs; OFF needs no chip.
    function forClimate(raw as String?) as Chip? {
        var icon = StateIcons.forClimateStatus(raw);
        if (icon == null) {
            return null;
        }
        return new Chip(Labels.climate(raw), icon, :outline);
    }

    // ------------------------------------------------------------ drawing

    // At least 20 px (B4), more when fēnix 8/9 scale FONT_XTINY up.
    function height() as Number {
        var h = Graphics.getFontHeight(Graphics.FONT_XTINY) + 2;
        return h < 20 ? 20 : h;
    }

    // Measured width of one chip on this Dc.
    function measure(dc as Dc, chip as Chip) as Number {
        return width(dc.getTextWidthInPixels(chip.text, Graphics.FONT_XTINY), iconFor(chip) != null);
    }

    // Draws one chip centred on cx with its top at y; returns its width.
    // Filled kinds use black text; under monochrome every fill becomes white.
    function draw(dc as Dc, cx as Number, y as Number, chip as Chip) as Number {
        var h = height();
        var w = measure(dc, chip);
        var x = cx - w / 2;
        var fill = null;
        if (chip.kind == :warn) {
            fill = Theme.WARNING;
        } else if (chip.kind == :error) {
            fill = Theme.DESTRUCTIVE;
        } else if (chip.kind == :accent) {
            fill = Theme.ACCENT;
        } else if (chip.kind == :white) {
            fill = Theme.TEXT_1;
        }
        var fg = Theme.c(Theme.TEXT_1);
        if (fill != null) {
            dc.setColor(Theme.c(fill), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, h / 2);
            fg = Theme.BG;
        } else {
            dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(x, y, w, h, h / 2);
        }
        var tx = x + PAD;
        var icon = iconFor(chip);
        if (icon != null) {
            NightIcons.draw(dc, icon, tx + 6, y + h / 2, 6, fg);
            tx += ICON_W;
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, y + h / 2, Graphics.FONT_XTINY, chip.text,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        return w;
    }

    // Draws a row centred on the screen; returns its total width.
    function drawRow(dc as Dc, y as Number, chips as Array<Chip>, gap as Number) as Number {
        var widths = [] as Array<Number>;
        for (var i = 0; i < chips.size(); i += 1) {
            widths.add(measure(dc, chips[i] as Chip));
        }
        var total = rowWidth(widths, gap);
        var x = dc.getWidth() / 2 - total / 2;
        for (var i = 0; i < chips.size(); i += 1) {
            var w = widths[i] as Number;
            draw(dc, x + w / 2, y, chips[i] as Chip);
            x += w + gap;
        }
        return total;
    }

}
