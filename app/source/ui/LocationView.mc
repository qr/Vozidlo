import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.PersistedContent;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Geometry of the Find my car screen (ui-improvements.md C5), for any
// display (decisions.md "Layouts follow the screen"; spec in
// tools/ui/devices/40-screens.js DS.fcParked / fcGps / fcMoving / fcMessage).
// Text sits inside the track, so on a round face every chord is measured on
// the track's text radius (g.textR, R - 6) with the ring-screen margin; that
// is what gives the PoC's address widths [158, 186] at y 46/65 on the
// fēnix 7 Pro. On the rectangle (Venu X1) it is the usable width. Pure:
// everything comes from g, so tests run every watch on one simulator.
module FindCarLayout {

    // Usable width for a glyph box from top to bottom inside the track.
    // While the action menu indicator shows (g.keepOut) the box also stays
    // left of it, as everywhere else (Geo.Display.span).
    function chordWidth(g as Geo.Display, top as Number, bottom as Number) as Number {
        var w;
        if (g.round) {
            w = TextBlock.lineWidth(g.textR, g.cy, top, bottom) - 2 * g.px(Theme.RING_MARGIN - TextBlock.MARGIN);
            var right = (g.span(top, bottom, 0)[1] as Number) - g.cx;
            if (2 * right < w) {
                w = 2 * right;
            }
        } else {
            w = g.usable(top, bottom, 16);
        }
        return w > 0 ? w : 0;
    }

    // w narrowed so a box level with the START glyph keeps px(4) clear of
    // it: on watches without a map START shows the menu glyph (M4), and the
    // second address line on the fēnix-sized faces runs into it.
    function clearOfStartGlyph(g as Geo.Display, top as Number, bottom as Number, w as Number) as Number {
        var p = g.anchor(:start);
        if (p == null) {
            return w;
        }
        var r = g.glyphIconR;
        if (bottom > p[1] - r && top < p[1] + r) {
            var limit = 2 * (p[0] - r - g.px(4) - g.cx);
            if (limit < w) {
                return limit > 0 ? limit : 0;
            }
        }
        return w;
    }

    // Per-line widths for a two-line address starting at `top`.
    function addressWidths(g as Geo.Display, top as Number, lineH as Number) as Array<Number> {
        return [chordWidth(g, top, top + lineH), chordWidth(g, top + lineH, top + 2 * lineH)] as Array<Number>;
    }

    // addressWidths() where START shows the menu glyph.
    function addressWidthsBesideGlyph(g as Geo.Display, top as Number, lineH as Number) as Array<Number> {
        var w = addressWidths(g, top, lineH);
        for (var i = 0; i < w.size(); i += 1) {
            var t = top + i * lineH;
            w[i] = clearOfStartGlyph(g, t, t + lineH, w[i] as Number);
        }
        return w;
    }

    // Top of "Waiting for GPS" in a font of height fontH: centred 2 px above
    // the middle (112 in small on the fēnix, as built).
    function gpsTop(g as Geo.Display, fontH as Number) as Number {
        return Math.round(g.cy - fontH / 2.0 - g.px(2)).toNumber();
    }

    // The tops of every block, in device px (fēnix 7 Pro in brackets, the
    // PoC's numbers). Stacked from the measured fonts, so a watch with
    // taller fonts moves the lower lines down instead of overlapping them.
    class Slots {
        // Parked / waiting for GPS: address [46], distance [88], age [172],
        // and the age under "Waiting for GPS" [172].
        public var addressTop as Number;
        public var distanceTop as Number;
        public var ageTop as Number;
        public var gpsAgeTop as Number;
        // Car is moving: hero word [90] (small fallback [92]), "Last
        // parked" [130], its address [150] and age [196].
        public var movingHeroTop as Number;
        public var movingHeroSmallTop as Number;
        public var lastParkedTop as Number;
        public var lastAddressTop as Number;
        public var lastAgeTop as Number;
        // No data / not supported / switched off / unavailable: the
        // message block is centred on this y [124].
        public var messageCentre as Number;

        function initialize(g as Geo.Display) {
            var f = g.fonts;
            var xt = f.xtinyH;
            addressTop = g.round ? g.px(46) : g.px(32);
            var addressBottom = addressTop + 2 * xt;
            distanceTop = addressBottom + g.px(4);
            // Anchored on the watch's hero font, also when a long distance
            // steps the number down, so the age never jumps.
            var heroH = g.heroFont == Graphics.FONT_NUMBER_MEDIUM ? f.numMedH : f.numMildH;
            ageTop = distanceTop + heroH + g.px(10);
            var below = addressBottom + f.smallH + g.px(30);
            var centred = Math.round(g.cy + f.smallH / 2.0 + g.px(26)).toNumber();
            gpsAgeTop = below > centred ? below : centred;

            movingHeroTop = g.cy - g.px(40);
            movingHeroSmallTop = g.cy - g.px(38);
            lastParkedTop = g.cy;
            lastAddressTop = g.cy + xt + g.px(1);
            lastAgeTop = lastAddressTop + 2 * xt + g.px(8);
            // M14: if the age would pass the status line, the moving block
            // moves up, never above the title line.
            var over = lastAgeTop + xt - (g.h - g.px(g.round ? 29 : 20));
            if (over > 0) {
                var room = movingHeroTop - g.titleTop;
                var up = over < room ? over : room;
                if (up > 0) {
                    movingHeroTop -= up;
                    movingHeroSmallTop -= up;
                    lastParkedTop -= up;
                    lastAddressTop -= up;
                    lastAgeTop -= up;
                }
            }
            messageCentre = g.cy - g.px(6);
        }
    }

    function slots(g as Geo.Display) as Slots {
        return new Slots(g);
    }

}

// What START does and the copy that names the menu, kept pure for the tests.
module FindCarLogic {

    // M7: the copy names no button, since vívoactive 6, Venu 4 and Venu X1
    // have no MENU key (was "MENU to refresh" / "MENU to try again").
    const REFRESH_HINT = "Refresh from the menu";
    const RETRY_HINT = "Try again from the menu";

    // M4: START opens the map when the car is parked and the watch has
    // MapView, otherwise the Find my car list (FR255, Venu 3 / 3S,
    // vívoactive 6, Venu 4, and every watch while the car is not parked).
    function startAction(parked as Boolean, map as Boolean) as Symbol {
        return parked && map ? :map : :list;
    }

}

// The find-my-car screen itself (US-028..US-033, C5). The model it draws
// (ParkingPosition, LocationMath, ParkingFeature, LastParked, CarNavigation)
// lives in model/Parking.mc. Back leaves it the normal, un-remapped way
// (docs/best-practices: this view never overrides onBack()).
class LocationView extends WatchUi.View {

    private var _section as ParkingPosition.Section? = null;
    private var _fetching as Boolean = false;
    private var _lastError as String? = null;
    // US-028's own note says fetch when the user opens this screen, but
    // onShow() re-fires every time a child view (the map, a confirmation,
    // the menu) pops back to this one, and re-spending quota on every one
    // of those would be wasteful. This flag makes the auto-fetch a
    // once-per-visit thing; the menu's own "Refresh" item is how a user asks
    // for a second one.
    private var _hasFetchedOnce as Boolean = false;

    private var _myPosition as Position.Location? = null;
    private var _myAccuracy as Position.Quality = Position.QUALITY_NOT_AVAILABLE;
    private var _myHeading as Double? = null;
    private var _positionEventsActive as Boolean = false;

    // Whether Garmin's action menu indicator shows here (no MENU key, M5);
    // text then keeps out of its band.
    private var _indicator as Boolean = false;

    function initialize() {
        View.initialize();
        _indicator = Input.enableIndicator(self);
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        // Monochrome flag is cached per onShow (A21).
        Theme.refresh();
        Geo.setKeepOut(_indicator);
        if (_section == null) {
            _section = ParkingPosition.fromCache();
        }
        _startPositionEvents();
        if (!_hasFetchedOnce) {
            refresh();
        }
    }

    // US-029's hard rule: a watch app that leaves GPS running after the
    // screen using it is gone is an explicit battery complaint in Garmin's
    // review guidelines. Symmetrical with _startPositionEvents(): every path
    // that turns events on is matched by exactly this one place turning them
    // off.
    function onHide() as Void {
        _stopPositionEvents();
    }

    // ------------------------------------------------------------ fetching

    // Returns why nothing was sent, or :ok (Refusal, the same checks and
    // order as Status). The automatic first fetch in onShow() ignores it:
    // the status line already shows a missing phone; only a Refresh the
    // user picked gets the reason as a toast (LocationMenuDelegate).
    function refresh() as Symbol {
        var verdict = Refusal.current(_fetching);
        if (verdict != :ok) {
            return verdict;
        }
        var settings = getApp().getSettings();

        _fetching = true;
        _hasFetchedOnce = true;
        _lastError = null;
        WatchUi.requestUpdate();

        // Only this section: same quota cost as the unfiltered read, and it
        // is also what makes PARKING_POSITION_UNSUPPORTED show up as a real
        // error rather than a silent, ambiguous omission (see
        // ParkingPosition._kindForAbsence).
        ApiClient.getVehicle(settings.vin, "parkingPosition", settings.apiKey, method(:_onVehicleResponse));
        return :ok;
    }

    function _onVehicleResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _fetching = false;

        if (responseCode == 200) {
            var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
            if (body != null) {
                var vehicle = body.get("vehicle") as Dictionary?;
                if (vehicle != null) {
                    var errors = body.get("errors") as Array?;
                    // Safe unconditionally: Cache.update() only ever touches
                    // sections actually present in `vehicle`, so a
                    // parkingPosition-only fetch can never clobber
                    // charging/status/etc cached by other screens.
                    Cache.update(vehicle, errors);
                    var parsed = ParkingPosition.parse(vehicle, errors, Time.now().value());
                    _section = parsed;
                    ParkingFeature.noteSupportKnown(parsed.kind);
                    LastParked.record(parsed);
                    _lastError = null;
                }
            }
            Quota.recordHeaders(null, null, null);
            WatchUi.requestUpdate();
            return;
        }

        var errorBody = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (errorBody != null) ? (errorBody.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        // Kept whole; the status line fits it by pixels (was a 40-char cut).
        _lastError = ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text;
        WatchUi.requestUpdate();
    }

    // ------------------------------------------------------------ position

    function _startPositionEvents() as Void {
        if (_positionEventsActive) {
            return;
        }
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:_onPosition));
        _positionEventsActive = true;
    }

    function _stopPositionEvents() as Void {
        if (!_positionEventsActive) {
            return;
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        _positionEventsActive = false;
    }

    // US-029: only ever updates in-memory state and redraws. Never touches
    // the network, so the bearing pointer tracks the user turning without
    // spending any of the hourly API quota.
    function _onPosition(info as Position.Info) as Void {
        _myPosition = info.position;
        _myAccuracy = info.accuracy;
        var heading = info.heading;
        _myHeading = (heading != null) ? (heading as Float).toDouble() : null;
        WatchUi.requestUpdate();
    }

    // ------------------------------------------------------------- actions

    // Navigate needs coordinates; the menu leaves it out otherwise (PoC
    // fc-moving: MENU is Refresh only).
    function canNavigate() as Boolean {
        var section = _section;
        return section != null && section.isParked();
    }

    // M4: what START (and a tap) does right now, :map or :list.
    function startAction() as Symbol {
        var section = _section;
        return FindCarLogic.startAction(section != null && section.isParked(), mapAvailable());
    }

    // Whether this build can show the map at all. The map code is compiled
    // only for watches with MapView (app/monkey.jungle excludes (:map) on
    // the others); the `has` check stays for firmware that lacks it anyway.
    // The SDK has no signal for "no map tile data for this area", only this.
    (:map)
    function mapAvailable() as Boolean {
        return WatchUi has :MapView;
    }

    (:nomap)
    function mapAvailable() as Boolean {
        return false;
    }

    // US-030: the map view is only ever constructed here, on demand, see
    // MapPreviewView's own comment on why that (and its own onHide()) is
    // what keeps this app's one real memory risk bounded.
    function openMap() as Void {
        var section = _section;
        if (section == null || !section.isParked() || !mapAvailable()) {
            return;
        }
        var carLocation = new Position.Location({
            :latitude => section.latitude as Double, :longitude => section.longitude as Double, :format => :degrees
        });
        _pushMap(carLocation, _myPosition);
    }

    (:map)
    function _pushMap(car as Position.Location, mine as Position.Location?) as Void {
        var map = new MapPreviewView(car, mine);
        WatchUi.pushView(map, new MapPreviewDelegate(map), Theme.SLIDE_IN);
    }

    // Never reached: openMap() checks mapAvailable() first.
    (:nomap)
    function _pushMap(car as Position.Location, mine as Position.Location?) as Void {
    }

    // US-032: only ever opens the confirmation. CarNavigation.start(), the
    // thing that actually calls System.exitTo(), is reached exclusively
    // through a "yes" on that dialog; see NavigateConfirmDelegate below.
    function confirmNavigate() as Void {
        var section = _section;
        if (section == null || !section.isParked()) {
            return;
        }
        NavigateConfirm.push(section.latitude as Double, section.longitude as Double);
    }

    // -------------------------------------------------------- rendering

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Theme.c(Theme.TEXT_1), Theme.BG);
        dc.clear();

        var section = _section;
        if (section == null) {
            section = ParkingPosition.fromCache();
            _section = section;
        }
        var g = Geo.current();
        var slots = FindCarLayout.slots(g);
        var toList = startAction() == :list;

        Bezel.track(dc);

        var statusY = 0;
        if (section.kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            statusY = _drawMessage(dc, g, slots, ["Not supported", "by this car"] as Array<String>, null);
        } else if (section.kind.equals(VehicleState.KIND_DISABLED)) {
            statusY = _drawMessage(dc, g, slots, ["Parking position is", "switched off for this car"] as Array<String>, null);
        } else if (section.kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            statusY = _drawUnavailable(dc, g, slots, toList);
        } else if (section.kind.equals(VehicleState.KIND_UNKNOWN)) {
            statusY = _drawMessage(dc, g, slots, ["No data yet"] as Array<String>, FindCarLogic.REFRESH_HINT);
        } else if (section.state != null && (section.state as String).equals("IN_MOTION")) {
            statusY = _drawMoving(dc, g, slots, toList);
        } else {
            statusY = _drawParked(dc, g, slots, section, toList);
        }

        _drawStatus(dc, g, statusY);

        // M4: START = map (accent arc, no text hint, B4) when the map can
        // open, with the menu glyph at UP on five-button watches; otherwise
        // START opens the list and carries the menu glyph itself.
        if (toList) {
            Bezel.glyphAt(dc, :start, :menu, Theme.TEXT_1, :accent);
        } else {
            Bezel.hintArcAt(dc, :start, :accent);
            Bezel.glyphAt(dc, :up, :menu, Theme.TEXT_2, null);
        }
        // Last, so the pointer is never covered by the START arc.
        _drawPointer(dc, section);
    }

    // Parked (PoC NF.parked) or waiting for a fix (NF.gps). Returns the y
    // for the status line.
    private function _drawParked(dc as Dc, g as Geo.Display, slots as FindCarLayout.Slots,
                                 section as ParkingPosition.Section, besideGlyph as Boolean) as Number {
        var h = g.fonts.xtinyH;
        _drawAddress(dc, g, slots.addressTop, ParkingPosition.displayAddress(section), besideGlyph);

        if (!section.hasCoordinates()) {
            // PARKED always carries gpsCoordinates per the schema, but never
            // trust that blindly: draw nothing further rather than crash.
            _drawAge(dc, g, slots.ageTop, section.age);
            return slots.ageTop + h + g.px(3);
        }
        if (!_hasFix()) {
            // US-029: say we're waiting for a fix rather than draw a wrong
            // bearing (C5: no pointer until a fix arrives).
            _drawWaitingForGps(dc, g);
            _drawAge(dc, g, slots.gpsAgeTop, section.age);
            return slots.gpsAgeTop + h + g.px(3);
        }

        var myDegrees = (_myPosition as Position.Location).toDegrees();
        var distance = LocationMath.distanceMeters(
            myDegrees[0], myDegrees[1], section.latitude as Double, section.longitude as Double);
        var parts = LocationMath.distanceParts(distance, System.getDeviceSettings().distanceUnits);
        _drawDistance(dc, g, slots.distanceTop, parts[0], parts[1]);
        _drawAge(dc, g, slots.ageTop, section.age);
        return slots.ageTop + h + g.px(3);
    }

    // "Waiting for GPS" in small, stepping down to tiny and xtiny where it
    // does not fit the track; centred a little above the middle.
    private function _drawWaitingForGps(dc as Dc, g as Geo.Display) as Void {
        var text = "Waiting for GPS";
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
        var font = Graphics.FONT_XTINY;
        for (var i = 0; i < fonts.size(); i += 1) {
            font = fonts[i] as Graphics.FontType;
            var y = FindCarLayout.gpsTop(g, dc.getFontHeight(font));
            if (dc.getTextWidthInPixels(text, font) <= FindCarLayout.chordWidth(g, y, y + dc.getFontHeight(font))) {
                break;
            }
        }
        _line(dc, g, FindCarLayout.gpsTop(g, dc.getFontHeight(font)), font, text, Theme.TEXT_2);
    }

    // The watch's hero number font plus unit (A8, M1); a step down to
    // NUMBER_MILD, then to the text font, when a long distance would run
    // into the track (fonts are scaled per watch, so measured here).
    private function _drawDistance(dc as Dc, g as Geo.Display, y as Number, value as String, unit as String) as Void {
        var nums = [g.heroFont, Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM] as Array<Graphics.FontType>;
        var units = [g.unitFont, Graphics.FONT_SMALL, Graphics.FONT_SMALL] as Array<Graphics.FontType>;
        var numFont = g.heroFont;
        var unitFont = g.unitFont;
        for (var i = 0; i < nums.size(); i += 1) {
            numFont = nums[i] as Graphics.FontType;
            unitFont = units[i] as Graphics.FontType;
            var total = dc.getTextWidthInPixels(value, numFont) + g.px(Ui.UNIT_GAP) + dc.getTextWidthInPixels(unit, unitFont);
            if (total <= FindCarLayout.chordWidth(g, y, y + dc.getFontHeight(numFont))) {
                break;
            }
        }
        Ui.drawValueWithUnit(dc, g.cx, y, value, unit, numFont, unitFont, Theme.TEXT_1);
    }

    // US-029: the bearing pointer on the ring, rotating with _myHeading
    // (updated purely from _onPosition(), no re-fetch). Outline while there
    // is no compass heading: LocationMath then falls back to north-up.
    private function _drawPointer(dc as Dc, section as ParkingPosition.Section) as Void {
        if (!section.isParked() || !_hasFix()) {
            return;
        }
        if (section.state != null && (section.state as String).equals("IN_MOTION")) {
            return;
        }
        var myDegrees = (_myPosition as Position.Location).toDegrees();
        var bearing = LocationMath.bearingDegrees(
            myDegrees[0], myDegrees[1], section.latitude as Double, section.longitude as Double);
        Bezel.pointer(dc, LocationMath.arrowAngleRadians(bearing, _myHeading), _myHeading != null);
    }

    private function _hasFix() as Boolean {
        return _myPosition != null && _myAccuracy != Position.QUALITY_NOT_AVAILABLE;
    }

    // PoC NF.moving: hero word, then where the car was last parked.
    private function _drawMoving(dc as Dc, g as Geo.Display, slots as FindCarLayout.Slots, besideGlyph as Boolean) as Number {
        var word = "Car is moving";
        var y = slots.movingHeroTop;
        var medium = Graphics.FONT_MEDIUM;
        // C5 says small; medium fits on the fēnix 7 Pro (PoC note), small is
        // the fallback where the font scale makes it too wide.
        if (dc.getTextWidthInPixels(word, medium) <= FindCarLayout.chordWidth(g, y, y + dc.getFontHeight(medium))) {
            Ui.drawHeroWord(dc, g.cx, y, word, null, Theme.TEXT_1);
        } else {
            _line(dc, g, slots.movingHeroSmallTop, Graphics.FONT_SMALL, word, Theme.TEXT_1);
        }
        _drawLastParked(dc, g, slots, besideGlyph);
        // Above the hero: below it the last-parked block fills the face.
        return y - g.fonts.xtinyH - g.px(8);
    }

    // US-033: temporarily unavailable keeps showing the last parked spot
    // when there is one.
    private function _drawUnavailable(dc as Dc, g as Geo.Display, slots as FindCarLayout.Slots, besideGlyph as Boolean) as Number {
        var lines = ["Temporarily unavailable"] as Array<String>;
        var hint = FindCarLogic.RETRY_HINT;
        if (LastParked.get() == null) {
            return _drawMessage(dc, g, slots, lines, hint);
        }
        _drawLastParked(dc, g, slots, besideGlyph);
        var end = slots.lastParkedTop - g.px(4);
        var font = _blockFont(dc, g, [lines[0], hint] as Array<String>, end, true);
        var h = dc.getFontHeight(font);
        var top = end - 2 * h;
        _line(dc, g, top, font, lines[0], Theme.TEXT_1);
        _line(dc, g, top + h, font, hint, Theme.TEXT_2);
        return top - g.fonts.xtinyH - g.px(4);
    }

    // US-033: the one place both IN_MOTION and _UNAVAILABLE reach for "where
    // the car was last actually parked", see the LastParked module comment
    // for why this cannot simply be Cache.section("parkingPosition").
    private function _drawLastParked(dc as Dc, g as Geo.Display, slots as FindCarLayout.Slots, besideGlyph as Boolean) as Void {
        var last = LastParked.get();
        if (last == null) {
            return;
        }
        var lastSection = last as ParkingPosition.Section;
        _line(dc, g, slots.lastParkedTop, Graphics.FONT_XTINY, "Last parked", Theme.TEXT_2);
        _drawAddress(dc, g, slots.lastAddressTop, ParkingPosition.displayAddress(lastSection), besideGlyph);
        _drawAge(dc, g, slots.lastAgeTop, lastSection.age);
    }

    // US-028: two chord-fitted lines, "…" when the address is longer (was a
    // 40-character cut on one line, A5). Clear of the START glyph when START
    // shows one (M4).
    private function _drawAddress(dc as Dc, g as Geo.Display, top as Number, address as String, besideGlyph as Boolean) as Void {
        var font = Graphics.FONT_XTINY;
        var h = dc.getFontHeight(font);
        var widths = besideGlyph ? FindCarLayout.addressWidthsBesideGlyph(g, top, h) : FindCarLayout.addressWidths(g, top, h);
        var lines = Ui.wrapFit(address, widths, 2, Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(g.cx, top + i * h, font, lines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // US-009 age line via Age (A17): grey, or amber "! 17 h ago" when stale.
    private function _drawAge(dc as Dc, g as Geo.Display, y as Number, capturedAt as Number?) as Void {
        var seconds = Age.elapsed(capturedAt, Time.now().value());
        var stale = seconds != null && Age.isStale(seconds);
        _line(dc, g, y, Graphics.FONT_XTINY, Age.line(seconds), stale ? Theme.WARNING : Theme.TEXT_2);
    }

    // The unsupported / disabled / unavailable / no-data texts of 1.0,
    // centred, in the largest font that fits every line inside the ring.
    // Returns the y for the status line.
    private function _drawMessage(dc as Dc, g as Geo.Display, slots as FindCarLayout.Slots,
                                  lines as Array<String>, hint as String?) as Number {
        var all = [] as Array<String>;
        all.addAll(lines);
        if (hint != null) {
            all.add(hint);
        }
        var centre = slots.messageCentre;
        var font = _blockFont(dc, g, all, centre, false);
        var h = dc.getFontHeight(font);
        var top = centre - (all.size() * h) / 2;
        for (var i = 0; i < all.size(); i += 1) {
            var color = (hint != null && i == all.size() - 1) ? Theme.TEXT_2 : Theme.TEXT_1;
            _line(dc, g, top + i * h, font, all[i] as String, color);
        }
        return top + all.size() * h + g.px(8);
    }

    // Largest of small/tiny/xtiny in which every line fits its chord, the
    // block either centred on `anchorY` or ending at it (endsAt).
    private function _blockFont(dc as Dc, g as Geo.Display, lines as Array<String>, anchorY as Number,
                                endsAt as Boolean) as Graphics.FontType {
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
        for (var f = 0; f < fonts.size() - 1; f += 1) {
            var font = fonts[f] as Graphics.FontType;
            var h = dc.getFontHeight(font);
            var top = endsAt ? anchorY - lines.size() * h : anchorY - (lines.size() * h) / 2;
            var fits = true;
            for (var i = 0; i < lines.size() && fits; i += 1) {
                var y = top + i * h;
                fits = dc.getTextWidthInPixels(lines[i] as String, font) <= FindCarLayout.chordWidth(g, y, y + h);
            }
            if (fits) {
                return font;
            }
        }
        return fonts[fonts.size() - 1] as Graphics.FontType;
    }

    // Phone, fetch and error feedback, one fitted xtiny line (1.0 drew it
    // under the title at y 30, which is gone).
    private function _drawStatus(dc as Dc, g as Geo.Display, y as Number) as Void {
        if (!(System.getDeviceSettings().phoneConnected)) {
            _line(dc, g, y, Graphics.FONT_XTINY, "! " + Commands.NO_PHONE, Theme.WARNING);
            return;
        }
        if (_fetching) {
            _line(dc, g, y, Graphics.FONT_XTINY, "Refreshing" + Labels.ELLIPSIS, Theme.TEXT_2);
            return;
        }
        var error = _lastError;
        if (error != null) {
            // "!" so the error survives the monochrome test (B1.2).
            _line(dc, g, y, Graphics.FONT_XTINY, "! " + error, Theme.DESTRUCTIVE);
        }
    }

    // One centred line fitted to the chord inside the track at its own y.
    private function _line(dc as Dc, g as Geo.Display, y as Number, font as Graphics.FontType, text as String,
                           color as Number) as Void {
        var h = dc.getFontHeight(font);
        var s = Ui.fit(text, FindCarLayout.chordWidth(g, y, y + h), Ui.measurer(dc, font));
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(g.cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
    }

}

// BehaviorDelegate, never InputDelegate (docs/best-practices). Never
// overrides onBack(): back leaves this screen the normal way.
class LocationDelegate extends WatchUi.BehaviorDelegate {

    // Weak: this delegate is owned by the view it acts on (pushed alongside
    // it), see docs/best-practices, "Break reference cycles with weak()".
    private var _view as WeakReference;

    function initialize(view as LocationView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    // US-030, M4: START (and a tap) is the direct, single-press way to ask
    // for the map (accent hint arc at START) when the car is parked and the
    // watch has MapView; otherwise it opens the Find my car list, so
    // Refresh never depends on a MENU key (it used to do nothing there).
    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            if (view.startAction() == :map) {
                view.openMap();
            } else {
                LocationMenu.push(view);
            }
        }
        return true;
    }

    // US-032/refresh: the secondary actions behind MENU.
    function onMenu() as Boolean {
        var view = _resolve();
        if (view != null) {
            LocationMenu.push(view);
        }
        return true;
    }

    // Watches without MENU (M5): the indicator or a swipe left opens the
    // same list.
    function onActionMenu() as Boolean {
        return onMenu();
    }

    private function _resolve() as LocationView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as LocationView?;
    }

}

// MENU on Find my car (B6, PoC NF.MENU_ITEMS): Navigate and Refresh as a
// NightMenu. "Navigate to car" became "Navigate": the context is on screen.
// Navigate only where the watch can save a waypoint (M13).
module LocationMenu {

    function push(view as LocationView) as Void {
        var menu = new NightMenu("Find my car", 0, null);
        if (view.canNavigate() && CarNavigation.isAvailable()) {
            menu.addItem(new NightMenuItem(:navigate, "Navigate", null, :pin, null));
        }
        menu.addItem(new NightMenuItem(:refresh, "Refresh", null, :refresh, null));
        WatchUi.pushView(menu, new LocationMenuDelegate(view), Theme.SLIDE_IN);
    }

}

// Pops first (NightMenuDelegate), so the confirmation lands on Find my car,
// not on the closing menu (A14).
class LocationMenuDelegate extends NightMenuDelegate {

    private var _view as WeakReference;

    function initialize(view as LocationView) {
        NightMenuDelegate.initialize(true);
        _view = view.weak();
    }

    function onPick(id as Object?) as Void {
        if (!_view.stillAlive()) {
            return;
        }
        var view = _view.get() as LocationView?;
        if (view == null) {
            return;
        }
        if (id == :navigate) {
            view.confirmNavigate();
        } else if (id == :refresh) {
            Refusal.toast(Refusal.text(view.refresh(), Quota.secondsUntilReset()));
        }
    }

}

// US-032: the app's own warning before navigation closes it, shared by Find
// my car and the map so both ask the same question.
module NavigateConfirm {

    const TEXT = "Navigate to the car? This closes the app.";

    function push(latitude as Double, longitude as Double) as Void {
        WatchUi.pushView(
            new WatchUi.Confirmation(TEXT),
            new NavigateConfirmDelegate(latitude, longitude),
            Theme.SLIDE_DIALOG
        );
    }

}

// US-032: fires only on an explicit "yes". This IS the "warn the user first
// that this closes the app"; CarNavigation.start() is never reached any
// other way.
class NavigateConfirmDelegate extends WatchUi.ConfirmationDelegate {

    private var _latitude as Double;
    private var _longitude as Double;

    function initialize(latitude as Double, longitude as Double) {
        ConfirmationDelegate.initialize();
        _latitude = latitude;
        _longitude = longitude;
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            CarNavigation.start(new Position.Location({
                :latitude => _latitude, :longitude => _longitude, :format => :degrees
            }));
        }
        return true;
    }

}
