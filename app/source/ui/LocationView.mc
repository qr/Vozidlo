import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Geometry of the Find my car screen (ui-improvements.md C5). Text sits
// inside the ring track, so every chord is measured on the track's inner
// edge (r 124 for a 2 px track at r 125) with the ring-screen margin; that is
// what gives the PoC's address widths [158, 186] at y 46/65.
module FindCarLayout {

    const TRACK_R = 125;
    const TRACK_PEN = 2;
    const TEXT_R = 124;

    // PoC NF.parked / NF.gps / NF.moving, tops of the glyph boxes.
    const ADDRESS_Y = 46;
    const DISTANCE_Y = 88;
    const GPS_Y = 112;
    const AGE_Y = 172;
    const MOVING_HERO_Y = 90;
    const MOVING_HERO_SMALL_Y = 92;
    const LAST_PARKED_Y = 130;
    const LAST_ADDRESS_Y = 150;
    const MESSAGE_CENTER_Y = 124;

    // Usable width for a glyph box from top to bottom inside the ring.
    function chordWidth(top as Number, bottom as Number) as Number {
        var w = TextBlock.lineWidth(TEXT_R, Bezel.C, top, bottom) - 2 * (Theme.RING_MARGIN - TextBlock.MARGIN);
        return w > 0 ? w : 0;
    }

    // Per-line widths for a two-line address starting at `top`.
    function addressWidths(top as Number, lineH as Number) as Array<Number> {
        return [chordWidth(top, top + lineH), chordWidth(top + lineH, top + 2 * lineH)] as Array<Number>;
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

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        // Monochrome flag is cached per onShow (A21).
        Theme.refresh();
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

    // US-030: the map view is only ever constructed here, on demand, see
    // MapPreviewView's own comment on why that (and its own onHide()) is
    // what keeps this app's one real memory risk bounded.
    function openMap() as Void {
        var section = _section;
        if (section == null || !section.isParked()) {
            return;
        }
        if (!(WatchUi has :MapView)) {
            // No cartography support to fall back on beyond the bearing view
            // already showing. The SDK has no signal for "no map tile data
            // for this specific area": only for "this build/device supports
            // MapView at all" (checked here), the best available proxy.
            return;
        }
        var carLocation = new Position.Location({
            :latitude => section.latitude as Double, :longitude => section.longitude as Double, :format => :degrees
        });
        var map = new MapPreviewView(carLocation, _myPosition);
        WatchUi.pushView(map, new MapPreviewDelegate(map), Theme.SLIDE_IN);
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

        _drawTrack(dc);

        var statusY = 0;
        if (section.kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            statusY = _drawMessage(dc, ["Not supported", "by this car"] as Array<String>, null);
        } else if (section.kind.equals(VehicleState.KIND_DISABLED)) {
            statusY = _drawMessage(dc, ["Parking position is", "switched off for this car"] as Array<String>, null);
        } else if (section.kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            statusY = _drawUnavailable(dc);
        } else if (section.kind.equals(VehicleState.KIND_UNKNOWN)) {
            statusY = _drawMessage(dc, ["No data yet"] as Array<String>, "MENU to refresh");
        } else if (section.state != null && (section.state as String).equals("IN_MOTION")) {
            statusY = _drawMoving(dc);
        } else {
            statusY = _drawParked(dc, section);
        }

        _drawStatus(dc, statusY);

        // START = map (no bottom hint text, B4); only when the map can open.
        if (section.isParked() && (WatchUi has :MapView)) {
            Bezel.hintArc(dc, Bezel.BTN_START, :accent);
        }
        // Last, so the pointer is never covered by the START arc.
        _drawPointer(dc, section);
    }

    private function _drawTrack(dc as Dc) as Void {
        dc.setPenWidth(FindCarLayout.TRACK_PEN);
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(Bezel.C, Bezel.C, FindCarLayout.TRACK_R);
        dc.setPenWidth(1);
    }

    // Parked (PoC NF.parked) or waiting for a fix (NF.gps). Returns the y
    // for the status line.
    private function _drawParked(dc as Dc, section as ParkingPosition.Section) as Number {
        var h = dc.getFontHeight(Graphics.FONT_XTINY);
        _drawAddress(dc, FindCarLayout.ADDRESS_Y, ParkingPosition.displayAddress(section));
        _drawAge(dc, FindCarLayout.AGE_Y, section.age);
        var statusY = FindCarLayout.AGE_Y + h + 3;

        if (!section.hasCoordinates()) {
            // PARKED always carries gpsCoordinates per the schema, but never
            // trust that blindly: draw nothing further rather than crash.
            return statusY;
        }
        if (!_hasFix()) {
            // US-029: say we're waiting for a fix rather than draw a wrong
            // bearing (C5: no pointer until a fix arrives).
            _line(dc, FindCarLayout.GPS_Y, Graphics.FONT_SMALL, "Waiting for GPS", Theme.TEXT_2);
            return statusY;
        }

        var myDegrees = (_myPosition as Position.Location).toDegrees();
        var distance = LocationMath.distanceMeters(
            myDegrees[0], myDegrees[1], section.latitude as Double, section.longitude as Double);
        var parts = LocationMath.distanceParts(distance, System.getDeviceSettings().distanceUnits);
        _drawDistance(dc, parts[0], parts[1]);
        return statusY;
    }

    // Number font plus unit (A8); a step down when a long distance would
    // run into the ring (fonts are scaled per watch, so measured here).
    private function _drawDistance(dc as Dc, value as String, unit as String) as Void {
        var y = FindCarLayout.DISTANCE_Y;
        var numFont = Graphics.FONT_NUMBER_MEDIUM;
        var unitFont = Graphics.FONT_MEDIUM;
        var maxW = FindCarLayout.chordWidth(y, y + dc.getFontHeight(numFont));
        var total = dc.getTextWidthInPixels(value, numFont) + Ui.UNIT_GAP + dc.getTextWidthInPixels(unit, unitFont);
        if (total > maxW) {
            numFont = Graphics.FONT_NUMBER_MILD;
            unitFont = Graphics.FONT_SMALL;
        }
        Ui.drawValueWithUnit(dc, Bezel.C, y, value, unit, numFont, unitFont, Theme.TEXT_1);
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
    private function _drawMoving(dc as Dc) as Number {
        var word = "Car is moving";
        var y = FindCarLayout.MOVING_HERO_Y;
        var medium = Graphics.FONT_MEDIUM;
        // C5 says small; medium fits on the fēnix 7 Pro (PoC note), small is
        // the fallback where the font scale makes it too wide.
        if (dc.getTextWidthInPixels(word, medium) <= FindCarLayout.chordWidth(y, y + dc.getFontHeight(medium))) {
            Ui.drawHeroWord(dc, Bezel.C, y, word, null, Theme.TEXT_1);
        } else {
            _line(dc, FindCarLayout.MOVING_HERO_SMALL_Y, Graphics.FONT_SMALL, word, Theme.TEXT_1);
        }
        _drawLastParked(dc);
        // Above the hero: below it the last-parked block fills the face.
        return y - dc.getFontHeight(Graphics.FONT_XTINY) - 8;
    }

    // US-033: temporarily unavailable keeps showing the last parked spot
    // when there is one.
    private function _drawUnavailable(dc as Dc) as Number {
        var lines = ["Temporarily unavailable"] as Array<String>;
        var hint = "MENU to try again";
        if (LastParked.get() == null) {
            return _drawMessage(dc, lines, hint);
        }
        _drawLastParked(dc);
        var font = _blockFont(dc, ["Temporarily unavailable", hint] as Array<String>, FindCarLayout.LAST_PARKED_Y - 4, true);
        var h = dc.getFontHeight(font);
        var top = FindCarLayout.LAST_PARKED_Y - 4 - 2 * h;
        _line(dc, top, font, lines[0], Theme.TEXT_1);
        _line(dc, top + h, font, hint, Theme.TEXT_2);
        return top - dc.getFontHeight(Graphics.FONT_XTINY) - 4;
    }

    // US-033: the one place both IN_MOTION and _UNAVAILABLE reach for "where
    // the car was last actually parked", see the LastParked module comment
    // for why this cannot simply be Cache.section("parkingPosition").
    private function _drawLastParked(dc as Dc) as Void {
        var last = LastParked.get();
        if (last == null) {
            return;
        }
        var lastSection = last as ParkingPosition.Section;
        var h = dc.getFontHeight(Graphics.FONT_XTINY);
        _line(dc, FindCarLayout.LAST_PARKED_Y, Graphics.FONT_XTINY, "Last parked", Theme.TEXT_2);
        _drawAddress(dc, FindCarLayout.LAST_ADDRESS_Y, ParkingPosition.displayAddress(lastSection));
        _drawAge(dc, FindCarLayout.LAST_ADDRESS_Y + 2 * h + 8, lastSection.age);
    }

    // US-028: two chord-fitted lines, "…" when the address is longer (was a
    // 40-character cut on one line, A5).
    private function _drawAddress(dc as Dc, top as Number, address as String) as Void {
        var font = Graphics.FONT_XTINY;
        var h = dc.getFontHeight(font);
        var lines = Ui.wrapFit(address, FindCarLayout.addressWidths(top, h), 2, Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(Bezel.C, top + i * h, font, lines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // US-009 age line via Age (A17): grey, or amber "! 17 h ago" when stale.
    private function _drawAge(dc as Dc, y as Number, capturedAt as Number?) as Void {
        var seconds = Age.elapsed(capturedAt, Time.now().value());
        var stale = seconds != null && Age.isStale(seconds);
        _line(dc, y, Graphics.FONT_XTINY, Age.line(seconds), stale ? Theme.WARNING : Theme.TEXT_2);
    }

    // The unsupported / disabled / unavailable / no-data texts of 1.0,
    // centred, in the largest font that fits every line inside the ring.
    // Returns the y for the status line.
    private function _drawMessage(dc as Dc, lines as Array<String>, hint as String?) as Number {
        var all = [] as Array<String>;
        all.addAll(lines);
        if (hint != null) {
            all.add(hint);
        }
        var font = _blockFont(dc, all, FindCarLayout.MESSAGE_CENTER_Y, false);
        var h = dc.getFontHeight(font);
        var top = FindCarLayout.MESSAGE_CENTER_Y - (all.size() * h) / 2;
        for (var i = 0; i < all.size(); i += 1) {
            var color = (hint != null && i == all.size() - 1) ? Theme.TEXT_2 : Theme.TEXT_1;
            _line(dc, top + i * h, font, all[i] as String, color);
        }
        return top + all.size() * h + 8;
    }

    // Largest of small/tiny/xtiny in which every line fits its chord, the
    // block either centred on `anchorY` or ending at it (endsAt).
    private function _blockFont(dc as Dc, lines as Array<String>, anchorY as Number, endsAt as Boolean) as Graphics.FontType {
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
        for (var f = 0; f < fonts.size() - 1; f += 1) {
            var font = fonts[f] as Graphics.FontType;
            var h = dc.getFontHeight(font);
            var top = endsAt ? anchorY - lines.size() * h : anchorY - (lines.size() * h) / 2;
            var fits = true;
            for (var i = 0; i < lines.size() && fits; i += 1) {
                var y = top + i * h;
                fits = dc.getTextWidthInPixels(lines[i] as String, font) <= FindCarLayout.chordWidth(y, y + h);
            }
            if (fits) {
                return font;
            }
        }
        return fonts[fonts.size() - 1] as Graphics.FontType;
    }

    // Phone, fetch and error feedback, one fitted xtiny line (1.0 drew it
    // under the title at y 30, which is gone).
    private function _drawStatus(dc as Dc, y as Number) as Void {
        if (!(System.getDeviceSettings().phoneConnected)) {
            _line(dc, y, Graphics.FONT_XTINY, "! " + Commands.NO_PHONE, Theme.WARNING);
            return;
        }
        if (_fetching) {
            _line(dc, y, Graphics.FONT_XTINY, "Refreshing" + Labels.ELLIPSIS, Theme.TEXT_2);
            return;
        }
        var error = _lastError;
        if (error != null) {
            // "!" so the error survives the monochrome test (B1.2).
            _line(dc, y, Graphics.FONT_XTINY, "! " + error, Theme.DESTRUCTIVE);
        }
    }

    // One centred line fitted to the chord inside the ring at its own y.
    private function _line(dc as Dc, y as Number, font as Graphics.FontType, text as String, color as Number) as Void {
        var h = dc.getFontHeight(font);
        var s = Ui.fit(text, FindCarLayout.chordWidth(y, y + h), Ui.measurer(dc, font));
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(Bezel.C, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
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

    // US-030: START is the direct, single-press way to ask for the map
    // (accent hint arc at START).
    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.openMap();
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

    private function _resolve() as LocationView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as LocationView?;
    }

}

// MENU on Find my car (B6, PoC NF.MENU_ITEMS): Navigate and Refresh as a
// NightMenu. "Navigate to car" became "Navigate": the context is on screen.
module LocationMenu {

    function push(view as LocationView) as Void {
        var menu = new NightMenu("Find my car", 0, null);
        if (view.canNavigate()) {
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
