import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// The home hero (PoC NH.hero, variant b; ui-improvements.md C1b): state of
// charge, up to three chips and one status line, drawn in the title area of
// the home CustomMenu, plus the SoC ring drawn over the whole menu. Data
// comes from Cache.mc only: the home never makes a request of its own, like
// the glance (US-034/041), so it appears instantly, cached data or none.
//
// Layout runs from the bottom of the title up (plan "Facts": only
// Theme.heroBottom() px of the title are on screen at focus 0, the rest is
// cut at the top): status line just above the focused row, chips above it,
// the SoC digits above those, in whichever number font still fits the chord
// and stays clear of the ring.
module HomeHero {

    // Air between the chips and the hero digits, and between the status line
    // and the chips. The glyph boxes carry their own leading on top of this.
    const HERO_GAP = 4;
    const LINE_GAP = 2;
    const CHIP_GAP = 6;
    // Digits whose top lands above this screen y would touch the ring at
    // r 126 at any useful width (chord at y 12 is 84 px inside the ring).
    const MIN_DIGIT_TOP = 12;

    // Everything the hero draws, gathered once per onShow / feedback change
    // so drawTitle() never reads Storage (onUpdate runs often).
    class Data {
        public var soc as String;
        public var socFrac as Float;
        public var charging as Boolean;
        public var chips as Array<Chips.Chip>;
        public var status as String;
        public var statusKind as Symbol;

        function initialize(socText as String, frac as Float, isCharging as Boolean,
                            chipList as Array<Chips.Chip>, statusText as String, kind as Symbol) {
            soc = socText;
            socFrac = frac;
            charging = isCharging;
            chips = chipList;
            status = statusText;
            statusKind = kind;
        }
    }

    // ------------------------------------------------------------ pure

    // "80" for 80 or 80.6 (whole percent, as the old strip showed it); a dash
    // when nothing is cached, which the number font cannot draw, so
    // Ui.drawValueWithUnit falls back to a text font for it (A8).
    function socText(raw as Object?) as String {
        if (raw == null) {
            return Labels.DASH;
        }
        if (raw instanceof Float) {
            return (raw as Float).toNumber().toString();
        }
        if (raw instanceof Double) {
            return (raw as Double).toNumber().toString();
        }
        if (raw instanceof Number || raw instanceof Long) {
            return raw.toString();
        }
        return Labels.DASH;
    }

    // Ring fill 0..1; no data is an empty track (PoC "empty ring track").
    function socFrac(raw as Object?) as Float {
        var v = 0.0;
        if (raw instanceof Float) {
            v = raw as Float;
        } else if (raw instanceof Double) {
            v = (raw as Double).toFloat();
        } else if (raw instanceof Number) {
            v = (raw as Number).toFloat();
        } else if (raw instanceof Long) {
            v = (raw as Long).toFloat();
        }
        v = v / 100.0;
        if (v < 0.0) {
            return 0.0;
        }
        return v > 1.0 ? 1.0 : v;
    }

    // One line, one place for every message (PoC "command feedback always
    // lands in one place"): the last command result wins, then a missing
    // phone (US-045), then the age of the hero's data (US-009, amber "!"
    // when stale). Returns [text, kind] for Ui.drawStatusLine.
    function statusLine(feedback as String?, feedbackKind as Symbol, phoneConnected as Boolean,
                        ageSeconds as Number?) as [String, Symbol] {
        if (feedback != null) {
            return [feedback, feedbackKind];
        }
        if (!phoneConnected) {
            return [Commands.NO_PHONE, :error];
        }
        if (ageSeconds != null && Age.isStale(ageSeconds)) {
            return [Age.line(ageSeconds), :warn];
        }
        return [Age.line(ageSeconds), :age];
    }

    // The command feedback HomeMenu keeps after an onShow(): dropped once
    // home has drawn it, kept while it has not been on screen yet (set
    // under a confirmation, or by a response that arrived while another
    // screen was on top).
    function feedbackAfterShow(feedback as String?, drawn as Boolean) as String? {
        return drawn ? null : feedback;
    }

    // Title-area y positions, bottom up: [status top, chips top, hero
    // baseline]. Without chips the hero sits straight on the status line.
    function slots(bottom as Number, statusH as Number, chipH as Number, hasChips as Boolean) as [Number, Number, Number] {
        var statusTop = bottom - statusH;
        var chipsTop = hasChips ? statusTop - LINE_GAP - chipH : statusTop;
        var baseline = chipsTop - HERO_GAP;
        return [statusTop, chipsTop, baseline];
    }

    // Approximate top of the digits for a font with this ascent: number
    // fonts leave about a fifth of the ascent empty above the digits
    // (fēnix 7 Pro numberMedium ascent 54, digits about 40; fr955 numberHot
    // 62 / 49). Rounded towards the larger digit so the check errs safe.
    function digitTop(baseline as Number, ascent as Number) as Number {
        return baseline - (ascent * 4 + 4) / 5;
    }

    // How many chips (from the front) fit one centred row of maxW: the
    // lock chip comes first and is the last to go (US-059).
    function chipsToKeep(widths as Array<Number>, gap as Number, maxW as Number) as Number {
        var n = widths.size();
        while (n > 0 && Chips.rowWidth(widths.slice(0, n) as Array<Number>, gap) > maxW) {
            n -= 1;
        }
        return n;
    }

    // ------------------------------------------------------------ data

    // Feedback text/kind is owned by HomeMenu (it outlives a rebuild of this
    // data); everything else is read fresh from Cache.
    function fromCache(feedback as String?, feedbackKind as Symbol) as Data {
        var charging = Cache.section("charging");
        var chargingRaw = (charging != null) ? (charging.get("state") as String?) : null;
        var socRaw = (charging != null) ? charging.get("batterySocPercent") : null;
        var status = Cache.section("status");
        var lockRaw = (status != null) ? (status.get("doorsLocked") as String?) : null;
        var ac = Cache.section("airConditioning");
        var climateRaw = (ac != null) ? (ac.get("state") as String?) : null;

        var chips = [] as Array<Chips.Chip>;
        var lock = Chips.forLock(lockRaw);
        if (lock != null) {
            chips.add(lock);
        }
        var plug = Chips.forCharging(chargingRaw);
        if (plug != null) {
            chips.add(plug);
        }
        var climate = Chips.forClimate(climateRaw);
        if (climate != null) {
            chips.add(climate);
        }

        // The hero value is the SoC, so its age is the charging section's
        // (each section ages separately, decisions.md "Data is not live");
        // the lock section stands in when no charging data was ever cached.
        var capturedAt = Cache.sectionAge("charging");
        if (capturedAt == null) {
            capturedAt = Cache.sectionAge("status");
        }
        var line = statusLine(feedback, feedbackKind, System.getDeviceSettings().phoneConnected,
            Age.elapsed(capturedAt, Time.now().value()));

        var isCharging = chargingRaw != null && chargingRaw.equals("CHARGING");
        return new Data(socText(socRaw), socFrac(socRaw), isCharging, chips, line[0], line[1]);
    }

    // ------------------------------------------------------------ drawing

    // Draws into the CustomMenu title dc. `off` maps title y to screen y at
    // focus 0, so every width is the chord where the line really appears.
    function draw(dc as Dc, data as Data) as Void {
        var h = dc.getHeight();
        var off = Theme.heroBottom() - h;
        var chipH = Chips.height();
        var statusH = Graphics.getFontHeight(Graphics.FONT_XTINY);
        var y = slots(h, statusH, chipH, data.chips.size() > 0);

        // Fitted to the ring margin first (the status line itself only keeps
        // the plain margin), leaving room for the "!" it adds to warnings.
        var kind = data.statusKind;
        var font = Graphics.FONT_XTINY;
        var lineW = Ui.usable(y[0] + off, y[0] + off + statusH, Theme.RING_MARGIN);
        if ((kind == :warn || kind == :error) && data.status.find("!") != 0) {
            lineW -= dc.getTextWidthInPixels("! ", font);
        }
        Ui.drawStatusLine(dc, y[0], Ui.fit(data.status, lineW, Ui.measurer(dc, font)), kind);

        if (data.chips.size() > 0) {
            var widths = [] as Array<Number>;
            for (var i = 0; i < data.chips.size(); i += 1) {
                widths.add(Chips.measure(dc, data.chips[i] as Chips.Chip));
            }
            var maxW = Ui.usable(y[1] + off, y[1] + off + chipH, Theme.RING_MARGIN);
            var keep = chipsToKeep(widths, CHIP_GAP, maxW);
            Chips.drawRow(dc, y[1], data.chips.slice(0, keep) as Array<Chips.Chip>, CHIP_GAP);
        }

        _drawSoc(dc, data.soc, y[2], off);
    }

    // "100" in the largest number font that clears the ring, "%" in a text
    // font on the same baseline (C1b, A8). A dash takes FONT_MEDIUM, as
    // Ui.drawValueWithUnit would pick for it anyway.
    function _drawSoc(dc as Dc, value as String, baseline as Number, off as Number) as Void {
        var unitFont = Graphics.FONT_SMALL;
        var font = Graphics.FONT_MEDIUM;
        var unit = null;
        if (Ui.isNumberGlyphs(value)) {
            unit = "%";
            var fit = new HeroFit(dc, baseline + off, dc.getTextWidthInPixels(unit, unitFont) + Ui.UNIT_GAP);
            font = Ui.pickFont(value,
                [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>,
                0, fit.method(:excess));
        }
        Ui.drawValueWithUnit(dc, dc.getWidth() / 2, baseline - Graphics.getFontAscent(font), value, unit,
            font, unitFont, Theme.TEXT_1);
    }

    // SoC ring over the whole menu (C1b "all states"): white fill, the
    // accent while charging (the accent chip says so in words as well).
    function drawRing(dc as Dc, data as Data) as Void {
        Bezel.ring(dc, data.socFrac, data.charging ? Theme.ACCENT : Theme.TEXT_1, null);
    }

    // Ui.pickFont's measuring callback for the hero: how many px the value
    // plus unit overrun the chord at that font's own digit top (<= 0 fits),
    // so each font is judged at the height it would actually reach. A font
    // whose digits would rise into the ring never fits.
    class HeroFit {
        private var _dc as Dc;
        private var _baseline as Number;
        private var _unitW as Number;

        function initialize(dc as Dc, screenBaseline as Number, unitW as Number) {
            _dc = dc;
            _baseline = screenBaseline;
            _unitW = unitW;
        }

        function excess(s as String, font as Graphics.FontType) as Number {
            var top = digitTop(_baseline, Graphics.getFontAscent(font));
            if (top < MIN_DIGIT_TOP) {
                return 9999;
            }
            var need = _dc.getTextWidthInPixels(s, font) + _unitW;
            return need - Ui.usable(top, _baseline, Theme.RING_MARGIN);
        }
    }

}
