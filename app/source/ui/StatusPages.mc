import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

// The status pages (docs/design/ui-improvements.md C2, PoC NS.page with the
// D7 dots and the D4 menu glyph): lock & doors, fuel & range, a short
// charging page, odometer and air conditioning.
//
// The pure half decides which pages exist and turns one section into a Page
// (display-ready strings, chips, colours) when data arrives, so onUpdate
// only draws (docs/best-practices "Pre-compute, then draw"). The drawing
// half follows the PoC coordinates, every line fitted to the circle.
module StatusPages {

    // Order the pages are offered in, unchanged from the old StatusView.
    const KEYS = ["status", "fuelStatus", "charging", "odometer", "airConditioning"] as Array<String>;

    // Lock grid order (PoC lockItems): the API field and its chip word.
    const LOCK_FIELDS = ["doors", "windows", "bonnet", "trunk", "lights", "sunroof"] as Array<String>;
    const LOCK_NAMES = ["Doors", "Windows", "Bonnet", "Trunk", "Lights", "Sunroof"] as Array<String>;

    // Layout, PoC NS.page on the 260 round face (C2 checks).
    const TITLE_Y = 34;
    const HERO_WORD_Y = 70;
    const HERO_VALUE_Y = 64;
    const LINES_Y = 142;
    const AC_LINES_Y = 128;
    const LINE_PITCH = 20;
    const MAX_LINES = 2;
    const AGE_Y = 192;
    const STATUS_Y = 212;
    const EMPTY_Y = 98;
    const EMPTY_SUB_Y = 136;
    const GRID_W = 89;
    const GRID_H = 22;
    const GRID_X = [38, 133] as Array<Number>;
    const GRID_Y = 116;

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
        var linesY as Number;
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
            linesY = StatusPages.LINES_Y;
            chips = [] as Array<Chips.Chip>;
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
            page.linesY = AC_LINES_Y;
        }
        page.capturedAt = section.age;
        return page;
    }

    // A7 and the kind distinctions of US-014/US-015: no data yet asks for a
    // refresh; unavailable may come back; switched off will not by itself.
    function _empty(key as String, kind as String) as Page {
        var page = new Page(key, :empty);
        if (kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            page.main = "Unavailable";
            page.sub = "START to try again";
        } else if (kind.equals(VehicleState.KIND_DISABLED)) {
            page.main = "Switched off";
            page.sub = "for this car";
        } else if (kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            // Only reachable as the never-empty fallback page.
            page.main = "Not supported";
            page.sub = "by this car";
        } else {
            page.main = "No data yet";
            page.sub = "START to refresh";
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

    // ------------------------------------------------------------ drawing

    // status: the model's transient line ([text, kind]) or null.
    function draw(dc as Dc, page as Page, idx as Number, count as Number, status as [String, Symbol]?) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        Ui.title(dc, page.title, TITLE_Y);

        var kind = page.kind;
        if (kind == :empty) {
            _drawEmpty(dc, page);
        } else if (kind == :lock) {
            Ui.drawHeroWord(dc, 130, HERO_WORD_Y, page.main, page.icon, page.color);
            _drawGrid(dc, page.chips);
        } else if (kind == :value) {
            _drawValue(dc, page);
            _drawLines(dc, page.lines, page.linesY);
        } else {
            Ui.drawHeroWord(dc, 130, HERO_WORD_Y, page.main, page.icon, page.color);
            _drawLines(dc, page.lines, page.linesY);
        }

        if (kind != :empty) {
            // US-009: this page's own age; amber "! 17 h ago" when stale.
            var seconds = Age.elapsed(page.capturedAt, Time.now().value());
            var stale = seconds != null && Age.isStale(seconds);
            Ui.drawStatusLine(dc, AGE_Y, Age.line(seconds), stale ? :warn : :age);
        }
        if (status != null) {
            Ui.drawStatusLine(dc, STATUS_Y, status[0], status[1]);
        }

        if (count > 1) {
            Bezel.pageDots(dc, idx, count);
        }
        Bezel.glyph(dc, Bezel.BTN_START, :menu, Theme.TEXT_1, :accent);
    }

    function _drawEmpty(dc as Dc, page as Page) as Void {
        var font = Graphics.FONT_SMALL;
        var h = dc.getFontHeight(font);
        var s = Ui.fit(page.main, Ui.usable(EMPTY_Y, EMPTY_Y + h, Theme.MARGIN), Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        dc.drawText(130, EMPTY_Y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
        var sub = page.sub;
        if (sub != null) {
            var xh = dc.getFontHeight(Graphics.FONT_XTINY);
            var t = Ui.fit(sub, Ui.usable(EMPTY_SUB_Y, EMPTY_SUB_Y + xh, Theme.MARGIN), Ui.measurer(dc, Graphics.FONT_XTINY));
            dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
            dc.drawText(130, EMPTY_SUB_Y, Graphics.FONT_XTINY, t, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Number hero with its unit, or with a state icon beside it (charging,
    // PoC heroValueIcon). fēnix 8/9 scale fonts, so when the medium number
    // font plus unit outgrows the chord, the milder number font takes over.
    function _drawValue(dc as Dc, page as Page) as Void {
        var y = HERO_VALUE_Y;
        var icon = page.icon;
        var iconW = icon != null ? 8 + 26 : 0;
        var numFont = Graphics.FONT_NUMBER_MEDIUM;
        var unitFont = Graphics.FONT_MEDIUM;
        var unit = page.unit;
        var maxW = Ui.usable(y, y + dc.getFontHeight(numFont), Theme.MARGIN);
        if (_valueWidth(dc, page.main, unit, numFont, unitFont) + iconW > maxW) {
            numFont = Graphics.FONT_NUMBER_MILD;
            unitFont = Graphics.FONT_SMALL;
        }
        var cx = 130 - iconW / 2;
        var w = Ui.drawValueWithUnit(dc, cx, y, page.main, unit, numFont, unitFont, Theme.TEXT_1);
        if (icon != null) {
            var drawn = Ui.isNumberGlyphs(page.main) ? numFont : Graphics.FONT_MEDIUM;
            var iy = y + Graphics.getFontAscent(drawn) * 62 / 100;
            NightIcons.draw(dc, icon, cx + w / 2 + 8 + 13, iy, 12, Theme.c(Theme.TEXT_1));
        }
    }

    function _valueWidth(dc as Dc, value as String, unit as String?, numFont as Graphics.FontType,
                         unitFont as Graphics.FontType) as Number {
        var nf = Ui.isNumberGlyphs(value) ? numFont : Graphics.FONT_MEDIUM;
        var w = dc.getTextWidthInPixels(value, nf);
        if (unit != null) {
            w += Ui.UNIT_GAP + dc.getTextWidthInPixels(unit, unitFont);
        }
        return w;
    }

    // Xtiny lines, each fitted to the chord at its own y (ring margin, as
    // the PoC lines()).
    function _drawLines(dc as Dc, lines as Array<String>, y0 as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var h = dc.getFontHeight(font);
        var n = lines.size() < MAX_LINES ? lines.size() : MAX_LINES;
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < n; i += 1) {
            var y = y0 + i * LINE_PITCH;
            var s = Ui.fit(lines[i] as String, Ui.usable(y, y + h, Theme.RING_MARGIN), Ui.measurer(dc, font));
            dc.drawText(130, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // 2x3 grid of fixed-size chips (C2): x 38/133, rows from y 116; a lone
    // last chip is centred. Taller when fēnix 8/9 scale FONT_XTINY up.
    function _drawGrid(dc as Dc, chips as Array<Chips.Chip>) as Void {
        var h = Chips.height() > GRID_H ? Chips.height() : GRID_H;
        var pitch = h + 2;
        var n = chips.size() < 6 ? chips.size() : 6;
        for (var i = 0; i < n; i += 1) {
            var row = i / 2;
            var alone = i == n - 1 && i % 2 == 0;
            var x = alone ? 130 - GRID_W / 2 : (GRID_X[i % 2] as Number);
            _gridChip(dc, x, GRID_Y + row * pitch, GRID_W, h, chips[i] as Chips.Chip);
        }
    }

    // PoC gridChip: amber fill with black "!" and text when open, a grey
    // outline with white text (and a check when closed) otherwise; icon and
    // text centred together in the fixed width.
    function _gridChip(dc as Dc, x as Number, y as Number, w as Number, h as Number, chip as Chips.Chip) as Void {
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
        var text = Ui.fit(chip.text, w - 30, Ui.measurer(dc, font));
        var icon = Chips.iconFor(chip);
        var iconW = icon != null ? 16 : 0;
        var x0 = x + (w - iconW - dc.getTextWidthInPixels(text, font)) / 2;
        if (icon != null) {
            NightIcons.draw(dc, icon, x0 + 6, y + h / 2, 6, fg);
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + iconW, y + h / 2, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
