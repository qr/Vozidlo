import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Text for the charging screens (US-023, docs/design/ui-improvements.md C3).
// The pure half decides which detail rows exist and what they say, so
// tests/ChargingFormatTests.mc covers "rows with missing data are left out"
// without a Dc; the drawing half fits those rows to the circle.
// ChargingLogic keeps the decisions (limit choices, gating, profiles).
module ChargingFormat {

    // Two xtiny rows fit between the state chip (y 134) and the age line
    // (y 202) on the fēnix 7 Pro (C3); a third would sit on the age.
    // Slots.maxRows says how many fit on this watch.
    const MAX_DETAIL_ROWS = 2;
    const SEP = " · ";

    // Vertical slots of the charging detail screen (spec DS.charging), from
    // the title top used and the hero font height. On the fēnix 7 Pro:
    // hero 58, chip 134, rows 160 at a 20 px pitch, age 202, no data 98 /
    // 136.
    class Slots {
        public var heroTop as Number;
        public var chipTop as Number;
        public var rowsTop as Number;
        public var pitch as Number;
        public var ageTop as Number;
        // Detail rows that end at least 2 px above the age line.
        public var maxRows as Number;
        public var noDataTop as Number;
        public var noDataSubTop as Number;

        function initialize(g as Geo.Display, tTop as Number, heroH as Number) {
            var xt = g.fonts.xtinyH;
            heroTop = ChargingFormat.heroTop(g, tTop);
            chipTop = heroTop + heroH + g.px(2);
            rowsTop = chipTop + g.chipH + g.px(5);
            pitch = xt + g.px(1);
            ageTop = g.chargingAgeTop;
            maxRows = 0;
            while (maxRows < MAX_DETAIL_ROWS && rowsTop + maxRows * pitch + xt <= ageTop - g.px(2)) {
                maxRows += 1;
            }
            noDataTop = g.cy - g.px(32);
            noDataSubTop = g.cy + g.px(6);
        }
    }

    // Vertical slots of a charging profile card (spec DS.profile), under a
    // title drawn at tTop (profileTitleTop(), or lower when it is long). On
    // the fēnix 7 Pro: name 70, chip 108, facts 136 at a 19 px pitch,
    // timers from 178 (4 px under the facts), last line by 216, states at
    // 104 / 136 and errors at 112.
    class ProfileSlots {
        public var nameTop as Number;
        public var chipTop as Number;
        public var factsTop as Number;
        public var pitch as Number;
        public var timerGap as Number;
        public var lastTop as Number;
        public var stateTop as Number;
        public var stateSubTop as Number;
        public var errorTop as Number;

        function initialize(g as Geo.Display, tTop as Number) {
            nameTop = tTop + g.fonts.tinyH + g.px(1);
            chipTop = nameTop + g.fonts.mediumH + g.px(1);
            factsTop = chipTop + g.chipH + g.px(7);
            pitch = g.fonts.xtinyH;
            timerGap = g.px(4);
            lastTop = g.h - g.px(44);
            stateTop = g.cy - g.px(26);
            stateSubTop = g.cy + g.px(6);
            errorTop = g.cy - g.px(18);
        }

        // How many timer lines from timersTop still start by lastTop.
        function timerRoom(timersTop as Number) as Number {
            if (timersTop > lastTop) {
                return 0;
            }
            return (lastTop - timersTop) / pitch + 1;
        }
    }

    // ------------------------------------------------------------ pure

    // Detail rows in priority order, at most maxRows: power and type while
    // a session runs, then when it ends, then range. C3: a row whose data
    // the car did not send is left out, never shown as "Label: —". While
    // charging the first two fill the space, so range (already on Status)
    // drops off, matching the PoC.
    function detailRows(powerKw as Object?, chargeType as String?, fullEpoch as Number?,
                        remainingMin as Object?, rangeMeters as Object?, maxRows as Number) as Array<String> {
        var candidates = [
            powerRow(powerKw, chargeType),
            fullRow(fullEpoch != null ? clockAt(fullEpoch) : null, remainingMin),
            rangeRow(rangeMeters)
        ] as Array<String?>;
        var rows = [] as Array<String>;
        for (var i = 0; i < candidates.size() && rows.size() < maxRows; i += 1) {
            var row = candidates[i];
            if (row != null) {
                rows.add(row);
            }
        }
        return rows;
    }

    // "7.2 kW · AC". chargeType OFF is left out: the state chip already
    // says the car is not charging, and "Not charging" twice reads as noise.
    function powerRow(powerKw as Object?, chargeType as String?) as String? {
        var parts = [] as Array<String>;
        var power = powerText(powerKw);
        if (power != null) {
            parts.add(power + " kW");
        }
        if (chargeType != null && !chargeType.equals("OFF")) {
            parts.add(Labels.chargeType(chargeType));
        }
        if (parts.size() == 0) {
            return null;
        }
        return parts.size() == 1 ? parts[0] : (parts[0] + SEP + parts[1]);
    }

    // "Full by 18:40 (95 min)"; either half alone when only one is known.
    // fullyChargedAt only comes from a live fetch (ChargingDetailView's
    // class comment), so the cached view usually shows "Full in 95 min".
    function fullRow(clock as String?, remainingMin as Object?) as String? {
        var minutes = toNumber(remainingMin);
        if (clock != null && minutes != null) {
            return "Full by " + clock + " (" + minutes.toString() + " min)";
        }
        if (clock != null) {
            return "Full by " + clock;
        }
        if (minutes != null) {
            return "Full in " + minutes.toString() + " min";
        }
        return null;
    }

    // "36 km range", rounded to the nearest km (the API reports metres).
    function rangeRow(rangeMeters as Object?) as String? {
        var meters = toNumber(rangeMeters);
        if (meters == null || meters < 0) {
            return null;
        }
        return ((meters + 500) / 1000).toString() + " km range";
    }

    // One decimal for a fractional power (7.4), whole numbers as they are.
    function powerText(powerKw as Object?) as String? {
        if (powerKw == null) {
            return null;
        }
        if (powerKw instanceof Float) {
            return (powerKw as Float).format("%.1f");
        }
        if (powerKw instanceof Double) {
            return (powerKw as Double).format("%.1f");
        }
        var n = toNumber(powerKw);
        return n != null ? n.toString() : null;
    }

    // "08:05". Same 24 h shape ProblemDetail uses for a Retry-After time.
    function clock(hour as Number, minute as Number) as String {
        return hour.format("%02d") + ":" + minute.format("%02d");
    }

    // fullyChargedAt as a local clock time (US-023).
    function clockAt(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return clock(info.hour as Number, info.min as Number);
    }

    // JSON numbers arrive as Number, Long, Float or Double depending on
    // magnitude and decimals; anything else (a string, a dictionary) is
    // treated as missing rather than guessed.
    function toNumber(value as Object?) as Number? {
        if (value instanceof Number) {
            return value as Number;
        }
        if (value instanceof Long) {
            return (value as Long).toNumber();
        }
        if (value instanceof Float) {
            return (value as Float).toNumber();
        }
        if (value instanceof Double) {
            return (value as Double).toNumber();
        }
        return null;
    }

    // Hero top of the detail screen: tucked 5 px into the title's leading.
    function heroTop(g as Geo.Display, tTop as Number) as Number {
        return tTop + g.fonts.tinyH - g.px(5);
    }

    function slots(g as Geo.Display, tTop as Number, heroH as Number) as Slots {
        return new Slots(g, tTop, heroH);
    }

    // The profiles title sits 6 px under the usual title top (y 40 on the
    // fēnix 7 Pro), since it is the longest title in the app.
    function profileTitleTop(g as Geo.Display) as Number {
        return g.titleTop + g.px(6);
    }

    function profileSlots(g as Geo.Display, tTop as Number) as ProfileSlots {
        return new ProfileSlots(g, tTop);
    }

    // ------------------------------------------------------------ drawing

    // Centred xtiny lines, each fitted to the outline at its own y with the
    // ring margin (PoC `lines`): the ring eats the outer 12 px (scaled).
    // Returns the y below the last line.
    function drawLines(dc as Dc, y0 as Number, pitch as Number, lines as Array<String>, color as Number) as Number {
        var font = Graphics.FONT_XTINY;
        var h = dc.getFontHeight(font);
        var measure = Ui.measurer(dc, font);
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        var y = y0;
        for (var i = 0; i < lines.size(); i += 1) {
            var s = Ui.fit(lines[i], Ui.usable(y, y + h, Theme.RING_MARGIN), measure);
            dc.drawText(dc.getWidth() / 2, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
            y += pitch;
        }
        return y;
    }

}
