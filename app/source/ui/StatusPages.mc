import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

// The status pages (docs/design/ui-improvements.md C2, PoC NS.page with the
// D7 dots and the D4 menu glyph): lock & doors, fuel & range, a short
// charging page, odometer and air conditioning.
//
// The pure half decides which pages exist and turns one section into a Page
// (display-ready strings, chips, colours) when data arrives, so onUpdate
// only draws (docs/best-practices "Pre-compute, then draw"). The layout is
// pure too (slots(), grid(), spec tools/ui/devices/40-screens.js DS.status):
// y positions stack from the title and the measured font heights, widths
// follow the outline, so the fēnix 7 Pro keeps the PoC coordinates and
// every other watch gets the same page in its own fonts.
module StatusPages {

    // Order the pages are offered in, unchanged from the old StatusView.
    const KEYS = ["status", "fuelStatus", "charging", "odometer", "airConditioning"] as Array<String>;

    // Lock grid order (PoC lockItems): the API field and its chip word.
    const LOCK_FIELDS = ["doors", "windows", "bonnet", "trunk", "lights", "sunroof"] as Array<String>;
    const LOCK_NAMES = ["Doors", "Windows", "Bonnet", "Trunk", "Lights", "Sunroof"] as Array<String>;

    // At most two detail lines under a hero (C2).
    const MAX_LINES = 2;

    // M12 squeeze steps, px of the 260 face: [word to grid gap, row gap,
    // clearance above the age line]. Tried in order until three rows fit.
    const SQUEEZE = [[9, 2, 3], [4, 2, 3], [4, 1, 3], [4, 1, 1]] as Array<Array<Number>>;

    // One page, ready to draw. kind: :empty (no data, unavailable, switched
    // off), :lock (hero word + chip grid), :value (number hero + lines),
    // :word (hero word + lines).
    class Page {
        var key as String;
        var title as String;
        var kind as Symbol;
        var main as String;
        var unit as String? = null;
        var sub as String? = null;
        var icon as Symbol? = null;
        var color as Number;
        var lines as Array<String>;
        var chips as Array<Chips.Chip>;
        // Capture time (epoch seconds) of this page's own section, so each
        // page ages separately (US-009); null reads "No data".
        var capturedAt as Number? = null;

        function initialize(pageKey as String, pageKind as Symbol) {
            key = pageKey;
            title = StatusPages.titleFor(pageKey);
            kind = pageKind;
            main = Labels.DASH;
            color = Theme.TEXT_1;
            lines = [] as Array<String>;
            chips = [] as Array<Chips.Chip>;
        }
    }

    // Vertical slots of a page on one display, stacked from the title top
    // actually used and the measured font heights (decisions.md "Layouts
    // follow the screen"). On the fēnix 7 Pro: value 64, word 70, grid 116,
    // AC lines 128, line pitch 20, age 192, status 212, empty 98 / 136.
    class Slots {
        public var valueTop as Number;
        public var wordTop as Number;
        // Grid top before any M12 squeeze (grid() works from wordTop).
        public var gridTop as Number;
        public var acLinesTop as Number;
        public var pitch as Number;
        public var ageTop as Number;
        public var statusTop as Number;
        public var emptyTop as Number;
        public var emptySubTop as Number;

        function initialize(g as Geo.Display, tTop as Number) {
            var f = g.fonts;
            valueTop = tTop + f.tinyH + g.px(1);
            wordTop = tTop + f.tinyH + g.px(7);
            gridTop = wordTop + f.mediumH + g.px(9);
            acLinesTop = wordTop + f.mediumH + g.px(21);
            pitch = f.xtinyH + g.px(1);
            statusTop = g.statusTop;
            ageTop = statusTop - f.xtinyH - g.px(1);
            emptyTop = g.cy - g.px(32);
            emptySubTop = g.cy + g.px(6);
        }
    }

    // M12 lock grid placement: two columns of equal chips, rows from top.
    // shown real items, then a "+N" chip when more > 0. On the fēnix 7 Pro
    // with five items: W 89 at x 38 / 133, chip height 22, pitch 24, top 116.
    class Grid {
        public var shown as Number;
        public var more as Number;
        public var w as Number;
        public var hc as Number;
        public var top as Number;
        public var pitch as Number;
        public var gap as Number;
        public var x0 as Number;
        public var gridW as Number;
        // Index into SQUEEZE that made it fit; fits false only for the last
        // resort (one chip and "+N" that still do not clear the age).
        public var step as Number = 0;
        public var fits as Boolean = false;

        function initialize(shownItems as Number, moreItems as Number) {
            shown = shownItems;
            more = moreItems;
            w = 0;
            hc = 0;
            top = 0;
            pitch = 0;
            gap = 0;
            x0 = 0;
            gridW = 0;
        }

        // Chips drawn, the "+N" chip included.
        function count() as Number {
            return more > 0 ? shown + 1 : shown;
        }

        // Left x of chip i; a lone last chip is centred under the pairs.
        function chipX(i as Number) as Number {
            if (i == count() - 1 && i % 2 == 0) {
                return x0 + (gridW - w + 1) / 2;
            }
            return x0 + (i % 2) * (w + gap);
        }

        function chipY(i as Number) as Number {
            return top + (i / 2) * pitch;
        }

        function bottom() as Number {
            return chipY(count() - 1) + hc;
        }
    }

    // ------------------------------------------------------------ pure

    function sectionFor(vehicle as VehicleState.Vehicle?, key as String) as VehicleState.Section {
        if (vehicle == null) {
            return new VehicleState.Section(VehicleState.KIND_UNKNOWN, null, {});
        }
        if (key.equals("status")) {
            return vehicle.status;
        }
        if (key.equals("charging")) {
            return vehicle.charging;
        }
        if (key.equals("fuelStatus")) {
            return vehicle.fuelStatus;
        }
        if (key.equals("odometer")) {
            return vehicle.odometer;
        }
        return vehicle.airConditioning;
    }

    // US-014/US-015: KIND_UNSUPPORTED (an explicit error, or a genuine absence
    // with none, VehicleState._kindForAbsence) hides a page permanently. Every
    // other kind keeps its place and is drawn distinctly. Never zero pages.
    function visibleKeys(vehicle as VehicleState.Vehicle?) as Array<String> {
        var visible = [] as Array<String>;
        for (var i = 0; i < KEYS.size(); i += 1) {
            var key = KEYS[i] as String;
            if (!sectionFor(vehicle, key).kind.equals(VehicleState.KIND_UNSUPPORTED)) {
                visible.add(key);
            }
        }
        if (visible.size() == 0) {
            visible.add("status");
        }
        return visible;
    }

    // Lock grid chips (A9, C2): open or on items first as amber "! Trunk",
    // closed or off as an outline with a check. UNSUPPORTED drops out (as
    // windows/sunroof did before) and so does a field with no value (nothing
    // to say about it). Anything else (UNKNOWN, a value this app has never
    // seen) is a neutral outline with no icon: a check would claim "closed".
    // There are at most six items for six grid cells, so an insecure item is
    // never cut.
    function lockItems(values as Dictionary) as Array<Chips.Chip> {
        var warn = [] as Array<Chips.Chip>;
        var rest = [] as Array<Chips.Chip>;
        for (var i = 0; i < LOCK_FIELDS.size(); i += 1) {
            var raw = values.get(LOCK_FIELDS[i]) as String?;
            if (raw == null || raw.equals("UNSUPPORTED")) {
                continue;
            }
            var name = LOCK_NAMES[i] as String;
            if (raw.equals("OPEN") || raw.equals("ON")) {
                warn.add(new Chips.Chip(name, null, :warn));
            } else if (raw.equals("CLOSED") || raw.equals("OFF")) {
                rest.add(new Chips.Chip(name, :check, :outline));
            } else {
                rest.add(new Chips.Chip(name, null, :outline));
            }
        }
        return warn.addAll(rest) as Array<Chips.Chip>;
    }

    // US-008: a missing value is a dash, never a zero; Floats lose their
    // fraction like before.
    function numberText(value as Object?) as String {
        if (value == null) {
            return Labels.DASH;
        }
        if (value instanceof Float || value instanceof Double) {
            return (value as Float or Double).toNumber().toString();
        }
        return value.toString();
    }

    function titleFor(key as String) as String {
        if (key.equals("status")) {
            return "Lock & doors";
        }
        if (key.equals("charging")) {
            return "Charging";
        }
        if (key.equals("fuelStatus")) {
            return "Fuel & range";
        }
        if (key.equals("odometer")) {
            return "Odometer";
        }
        return "Air conditioning";
    }

    // One section to one Page. Pure: everything the draw needs except the
    // clock-dependent age text.
    function build(key as String, section as VehicleState.Section) as Page {
        if (!section.isPresent()) {
            return _empty(key, section.kind);
        }
        var values = section.values;
        var page;
        if (key.equals("status")) {
            page = new Page(key, :lock);
            var lock = values.get("doorsLocked") as String?;
            page.main = Labels.lock(lock);
            page.icon = StateIcons.forLockStatus(lock);
            // US-010: the word carries the meaning; amber only reinforces it.
            page.color = Labels.isInsecureLock(lock) ? Theme.WARNING : Theme.TEXT_1;
            page.chips = lockItems(values);
        } else if (key.equals("fuelStatus")) {
            page = new Page(key, :value);
            var range = values.get("totalRangeInKm");
            page.main = numberText(range);
            page.unit = range != null ? "km" : null;
            page.lines = _engineLines(values);
        } else if (key.equals("charging")) {
            page = new Page(key, :value);
            var soc = values.get("batterySocPercent");
            page.main = soc != null ? numberText(soc) + "%" : Labels.DASH;
            var state = values.get("state") as String?;
            page.icon = StateIcons.forChargingStatus(state);
            page.lines = _chargingLines(values, state);
        } else if (key.equals("odometer")) {
            page = new Page(key, :value);
            var mileage = values.get("mileageKm");
            page.main = numberText(mileage);
            page.unit = mileage != null ? "km" : null;
        } else {
            page = new Page(key, :word);
            var climate = values.get("state") as String?;
            page.main = Labels.climate(climate);
            var active = StateIcons.forClimateStatus(climate);
            page.icon = active != null ? active : :fan;
            page.lines = _heatingLines(values);
        }
        page.capturedAt = section.age;
        return page;
    }

    // A7 and the kind distinctions of US-014/US-015: no data yet asks for a
    // refresh; unavailable may come back; switched off will not by itself.
    // The hints name the menu, not a button (M7): the action list opens
    // from START, MENU or the action menu, depending on the watch.
    function _empty(key as String, kind as String) as Page {
        var page = new Page(key, :empty);
        if (kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            page.main = "Unavailable";
            page.sub = "Try again from the menu";
        } else if (kind.equals(VehicleState.KIND_DISABLED)) {
            page.main = "Switched off";
            page.sub = "for this car";
        } else if (kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            // Only reachable as the never-empty fallback page.
            page.main = "Not supported";
            page.sub = "by this car";
        } else {
            page.main = "No data yet";
            page.sub = "Refresh from the menu";
        }
        return page;
    }

    // US-011: each engine with its own type word ("Petrol 62%").
    function _engineLines(values as Dictionary) as Array<String> {
        var lines = [] as Array<String>;
        var engines = [values.get("primary"), values.get("secondary")] as Array<Dictionary?>;
        for (var i = 0; i < engines.size(); i += 1) {
            var engine = engines[i];
            if (engine != null) {
                var percent = engine.get("percent");
                var text = percent != null ? numberText(percent) + "%" : Labels.DASH;
                lines.add(Labels.engine(engine.get("engineType") as String?) + " " + text);
            }
        }
        return lines;
    }

    // The short charging page (D2: details live on the charging screen):
    // state, then range, then time to full, at most MAX_LINES of them.
    function _chargingLines(values as Dictionary, state as String?) as Array<String> {
        var lines = [Labels.charging(state)] as Array<String>;
        var rangeMeters = values.get("rangeMeters");
        if (rangeMeters instanceof Number) {
            lines.add(((rangeMeters as Number) / 1000).toString() + " km range");
        }
        var remainingMinutes = values.get("remainingMinutes");
        if (remainingMinutes != null && lines.size() < MAX_LINES) {
            lines.add(numberText(remainingMinutes) + " min to full");
        }
        return lines;
    }

    // US-019: front and rear separately; UNSUPPORTED and never-reported stay
    // absent rather than being shown as anything. "Windscreen" per the PoC
    // resolutions.
    function _heatingLines(values as Dictionary) as Array<String> {
        var lines = [] as Array<String>;
        var front = values.get("windowHeatingFront") as String?;
        if (front != null && !front.equals("UNSUPPORTED")) {
            lines.add("Windscreen heat " + Labels.openClosed(front).toLower());
        }
        var rear = values.get("windowHeatingRear") as String?;
        if (rear != null && !rear.equals("UNSUPPORTED")) {
            lines.add("Rear window heat " + Labels.openClosed(rear).toLower());
        }
        return lines;
    }

    // Slots of a page on display g under a title drawn at tTop.
    function slots(g as Geo.Display, tTop as Number) as Slots {
        return new Slots(g, tTop);
    }

    // Measured FONT_XTINY widths of the chip labels, for grid().
    function labelWidths(chips as Array<Chips.Chip>, measure as Method(s as String) as Number) as Array<Number> {
        var widths = [] as Array<Number>;
        for (var i = 0; i < chips.size(); i += 1) {
            widths.add(measure.invoke((chips[i] as Chips.Chip).text));
        }
        return widths;
    }

    // M12: the lock grid for labels of these widths (insecure items first,
    // as lockItems() sorts them) under a hero word ending at wordBottom.
    // Chips are as wide as the longest label needs (89 at least), capped by
    // the room of the paired rows; the indicator keep-out only limits the
    // right edge (Geo.Display.span), so the grid shifts left rather than
    // shrinking. When three rows do not fit above the age line the spacing
    // is squeezed first (SQUEEZE); only then two rows with "+N", and as a
    // large-font last resort one chip and "+N". Insecure items sort first,
    // so they are the ones shown.
    function grid(g as Geo.Display, widths as Array<Number>, wordBottom as Number, ageTop as Number) as Grid {
        var n = widths.size() < 6 ? widths.size() : 6;
        var longest = 0;
        for (var i = 0; i < n; i += 1) {
            if ((widths[i] as Number) > longest) {
                longest = widths[i] as Number;
            }
        }
        var t = _squeezed(g, n, 0, longest, wordBottom, ageTop);
        if (t == null && n > 4) {
            t = _squeezed(g, 3, n - 3, longest, wordBottom, ageTop);
        }
        if (t == null && n > 2) {
            t = _squeezed(g, 1, n - 1, longest, wordBottom, ageTop);
        }
        if (t == null) {
            var last = SQUEEZE.size() - 1;
            t = n > 2 ? _gridAt(g, 1, n - 1, longest, wordBottom, ageTop, last)
                      : _gridAt(g, n, 0, longest, wordBottom, ageTop, last);
        }
        return t;
    }

    // The first squeeze step at which this many chips fit, else null.
    function _squeezed(g as Geo.Display, shown as Number, more as Number, longest as Number,
                       wordBottom as Number, ageTop as Number) as Grid? {
        for (var i = 0; i < SQUEEZE.size(); i += 1) {
            var t = _gridAt(g, shown, more, longest, wordBottom, ageTop, i);
            if (t.fits) {
                return t;
            }
        }
        return null;
    }

    function _gridAt(g as Geo.Display, shown as Number, more as Number, longest as Number,
                     wordBottom as Number, ageTop as Number, step as Number) as Grid {
        var sq = SQUEEZE[step] as Array<Number>;
        var t = new Grid(shown, more);
        var count = t.count();
        t.step = step;
        t.hc = g.fonts.xtinyH + g.px(3);
        t.gap = g.px(6);
        t.top = wordBottom + g.px(sq[0] as Number);
        t.pitch = t.hc + g.px(sq[1] as Number);
        var pairRows = count / 2 > 1 ? count / 2 : 1;
        var sp = g.span(t.top, t.top + (pairRows - 1) * t.pitch + t.hc, Theme.RING_MARGIN);
        var want = longest + g.px(30);
        var minW = g.px(89);
        var w = want > minW ? want : minW;
        var cap = (sp[1] - sp[0] - t.gap) / 2;
        t.w = w < cap ? w : cap;
        t.gridW = 2 * t.w + t.gap;
        var centred = g.cx - t.gridW / 2;
        var shifted = sp[1] - t.gridW;
        t.x0 = centred < shifted ? centred : shifted;
        t.fits = t.bottom() <= ageTop - g.px(sq[2] as Number);
        return t;
    }

    // The "+N" chip: amber when it hides an open item, so "all closed"
    // is never implied by what is left on screen.
    function moreChip(chips as Array<Chips.Chip>, from as Number) as Chips.Chip {
        var warn = false;
        for (var i = from; i < chips.size(); i += 1) {
            if ((chips[i] as Chips.Chip).kind == :warn) {
                warn = true;
            }
        }
        return new Chips.Chip("+" + (chips.size() - from).toString(), null, warn ? :warn : :outline);
    }

    // ------------------------------------------------------------ drawing

    // status: the model's transient line ([text, kind]) or null.
    function draw(dc as Dc, page as Page, idx as Number, count as Number, status as [String, Symbol]?) as Void {
        var g = Geo.current();
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        var sl = slots(g, Ui.title(dc, page.title, g.titleTop));

        var kind = page.kind;
        if (kind == :empty) {
            _drawEmpty(dc, g, sl, page);
        } else if (kind == :lock) {
            Ui.drawHeroWord(dc, g.cx, sl.wordTop, page.main, page.icon, page.color);
            _drawGrid(dc, g, sl, page.chips);
        } else if (kind == :value) {
            var bottom = _drawValue(dc, g, sl.valueTop, page);
            _drawLines(dc, g, sl, page.lines, bottom + g.px(4));
        } else {
            Ui.drawHeroWord(dc, g.cx, sl.wordTop, page.main, page.icon, page.color);
            _drawLines(dc, g, sl, page.lines, sl.acLinesTop);
        }

        if (kind != :empty) {
            // US-009: this page's own age; amber "! 17 h ago" when stale.
            var seconds = Age.elapsed(page.capturedAt, Time.now().value());
            var stale = seconds != null && Age.isStale(seconds);
            Ui.drawStatusLine(dc, sl.ageTop, Age.line(seconds), stale ? :warn : :age);
        }
        if (status != null) {
            Ui.drawStatusLine(dc, sl.statusTop, status[0], status[1]);
        }

        if (count > 1) {
            Bezel.pageDots(dc, idx, count);
        }
        Bezel.glyphAt(dc, :start, :menu, Theme.TEXT_1, :accent);
    }

    function _drawEmpty(dc as Dc, g as Geo.Display, sl as Slots, page as Page) as Void {
        var font = Graphics.FONT_SMALL;
        var y = sl.emptyTop;
        var s = Ui.fit(page.main, Ui.usable(y, y + g.fonts.smallH, Theme.MARGIN), Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        dc.drawText(g.cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
        var sub = page.sub;
        if (sub != null) {
            var sy = sl.emptySubTop;
            var t = Ui.fit(sub, Ui.usable(sy, sy + g.fonts.xtinyH, Theme.MARGIN), Ui.measurer(dc, Graphics.FONT_XTINY));
            dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
            dc.drawText(g.cx, sy, Graphics.FONT_XTINY, t, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Number hero with its unit, or with a state icon beside it (charging,
    // PoC heroValueIcon), in the watch's hero font (M1). When it outgrows
    // the outline (fēnix 8/9 and a large user font scale the system fonts)
    // the milder number font takes over, and as a last resort the digits
    // go to FONT_MEDIUM. Returns the bottom of the number box, from which
    // the lines below stack.
    function _drawValue(dc as Dc, g as Geo.Display, y as Number, page as Page) as Number {
        var icon = page.icon;
        var iconW = icon != null ? g.px(8) + g.px(26) : 0;
        var unit = page.unit;
        var nums = [g.heroFont, Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>;
        var units = [g.unitFont, Graphics.FONT_SMALL, Graphics.FONT_SMALL] as Array<Graphics.FontType>;
        var numFont = nums[0] as Graphics.FontType;
        var unitFont = units[0] as Graphics.FontType;
        for (var i = 0; i < nums.size(); i += 1) {
            numFont = nums[i] as Graphics.FontType;
            unitFont = units[i] as Graphics.FontType;
            var maxW = Ui.usable(y, y + dc.getFontHeight(numFont), Theme.MARGIN);
            if (_valueWidth(dc, g, page.main, unit, numFont, unitFont) + iconW <= maxW) {
                break;
            }
        }
        var cx = g.cx - iconW / 2;
        var w = Ui.drawValueWithUnit(dc, cx, y, page.main, unit, numFont, unitFont, Theme.TEXT_1);
        if (icon != null) {
            var drawn = Ui.isNumberGlyphs(page.main) ? numFont : Graphics.FONT_MEDIUM;
            var iy = y + Graphics.getFontAscent(drawn) * 62 / 100;
            NightIcons.draw(dc, icon, cx + w / 2 + g.px(8) + g.px(13), iy, g.px(12), Theme.c(Theme.TEXT_1));
        }
        return y + dc.getFontHeight(numFont);
    }

    function _valueWidth(dc as Dc, g as Geo.Display, value as String, unit as String?, numFont as Graphics.FontType,
                         unitFont as Graphics.FontType) as Number {
        var nf = Ui.isNumberGlyphs(value) ? numFont : Graphics.FONT_MEDIUM;
        var w = dc.getTextWidthInPixels(value, nf);
        if (unit != null) {
            w += g.px(Ui.UNIT_GAP) + dc.getTextWidthInPixels(unit, unitFont);
        }
        return w;
    }

    // Xtiny lines, each fitted to the outline at its own y (ring margin, as
    // the PoC lines()). A line that would reach the age line is dropped,
    // the last one first.
    function _drawLines(dc as Dc, g as Geo.Display, sl as Slots, lines as Array<String>, y0 as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var h = g.fonts.xtinyH;
        var limit = sl.ageTop - g.px(2);
        var n = lines.size() < MAX_LINES ? lines.size() : MAX_LINES;
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < n; i += 1) {
            var y = y0 + i * sl.pitch;
            if (y + h > limit) {
                break;
            }
            var s = Ui.fit(lines[i] as String, Ui.usable(y, y + h, Theme.RING_MARGIN), Ui.measurer(dc, font));
            dc.drawText(g.cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // M12 grid of equal chips (grid()); x 38 / 133 from y 116 on the fēnix
    // 7 Pro, a lone last chip centred.
    function _drawGrid(dc as Dc, g as Geo.Display, sl as Slots, chips as Array<Chips.Chip>) as Void {
        var measure = Ui.measurer(dc, Graphics.FONT_XTINY);
        var t = grid(g, labelWidths(chips, measure), sl.wordTop + g.fonts.mediumH, sl.ageTop);
        for (var i = 0; i < t.count(); i += 1) {
            var chip = i < t.shown ? chips[i] as Chips.Chip : moreChip(chips, t.shown);
            _gridChip(dc, g, t.chipX(i), t.chipY(i), t.w, t.hc, chip, measure);
        }
    }

    // PoC gridChip: amber fill with black "!" and text when open, a grey
    // outline with white text (and a check when closed) otherwise; icon and
    // text centred together in the fixed width. The width was sized for the
    // label plus 30 px; where the room capped it, the label may use 3 px of
    // each side before it is cut.
    function _gridChip(dc as Dc, g as Geo.Display, x as Number, y as Number, w as Number, h as Number,
                       chip as Chips.Chip, measure as Method(s as String) as Number) as Void {
        var warn = chip.kind == :warn;
        var fg = warn ? Theme.BG : Theme.c(Theme.TEXT_1);
        if (warn) {
            dc.setColor(Theme.c(Theme.WARNING), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, h / 2);
        } else {
            dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(x, y, w, h, h / 2);
        }
        var font = Graphics.FONT_XTINY;
        var text = Ui.fit(chip.text, w - g.px(24), measure);
        var icon = Chips.iconFor(chip);
        var iconW = icon != null ? g.px(16) : 0;
        var x0 = x + (w - iconW - measure.invoke(text)) / 2;
        if (icon != null) {
            NightIcons.draw(dc, icon, x0 + g.px(6), y + h / 2, g.px(6), fg);
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + iconW, y + h / 2, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
