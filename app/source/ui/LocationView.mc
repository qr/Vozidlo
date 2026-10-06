import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.PersistedContent;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Graphics;

// Task 9 (US-028..US-033): "find my car". Address, distance/bearing, a map
// and navigation, for whatever the API's parkingPosition section last said.
//
// Deliberately NOT built on VehicleState.mc/Cache.mc's own parkingPosition
// handling: VehicleState.Vehicle has no parkingPosition field at all (task 6
// never needed one), and Cache.mc, though it already has a
// "parkingPosition" section: is owned by an earlier task and off limits to
// this one (see this task's file-ownership rules). ParkingPosition below is
// this task's own small, pure parser, mirroring VehicleState.mc's shape
// (same KIND_* constants, reused rather than redefined) so the rest of the
// app stays consistent even though the parsing code itself is separate, see
// VehicleState.mc's own comment on why duplicating a small piece of logic
// beats reaching across a task's ownership boundary into a module with no
// real "private" (Monkey C modules can't enforce it).
module ParkingPosition {

    // One parkingPosition reading. `state` is the raw API value ("PARKED"/
    // "IN_MOTION"/null) kept verbatim, never translated, matching every other
    // parser in this app's "tolerate values we don't recognise" rule.
    // `age` is null only for KIND_UNKNOWN (nothing cached, nothing fetched
    // yet): parkingPosition itself carries no carCapturedTimestamp field at
    // all (see openapi.json's ParkingPosition schema), so for every other
    // kind `age` is "when this was fetched or cached", exactly mirroring
    // Cache.mc's own fallback for this same section.
    class Section {
        public var kind as String;
        public var age as Number?;
        public var state as String?;
        public var latitude as Double?;
        public var longitude as Double?;
        public var address as String?;

        function initialize(
            sectionKind as String, sectionAge as Number?, sectionState as String?,
            sectionLatitude as Double?, sectionLongitude as Double?, sectionAddress as String?
        ) {
            kind = sectionKind;
            age = sectionAge;
            state = sectionState;
            latitude = sectionLatitude;
            longitude = sectionLongitude;
            address = sectionAddress;
        }

        function isPresent() as Boolean {
            return kind.equals(VehicleState.KIND_PRESENT);
        }

        function hasCoordinates() as Boolean {
            return latitude != null && longitude != null;
        }

        // "Actionable position", not "state says PARKED": coordinates only
        // ever appear when the vehicle really is parked (IN_MOTION never
        // carries any per openapi.json), so this is the one check
        // openMap()/confirmNavigate()/the bottom hint all need, without
        // depending on the exact spelling of a state string.
        function isParked() as Boolean {
            return isPresent() && hasCoordinates();
        }
    }

    // vehicle: response.get("vehicle"). errors: response.get("errors"), may
    // be null. now: Time.now().value() at parse time, see the module
    // comment above for why that, and not a carCapturedTimestamp, is this
    // section's age.
    function parse(vehicle as Dictionary, errors as Array?, now as Number) as Section {
        var raw = vehicle.get("parkingPosition") as Dictionary?;
        if (raw != null) {
            var coords = raw.get("gpsCoordinates") as Dictionary?;
            var latitude = (coords != null) ? _toDouble(coords.get("latitude")) : null;
            var longitude = (coords != null) ? _toDouble(coords.get("longitude")) : null;
            return new Section(
                VehicleState.KIND_PRESENT, now, raw.get("state") as String?,
                latitude, longitude, raw.get("formattedAddress") as String?
            );
        }
        return new Section(_kindForAbsence(errors), null, null, null, null, null);
    }

    // Same three-way classification VehicleState._kindForAbsence uses for
    // every other section (US-033), duplicated rather than called into:
    // see the module comment above. Falls back to KIND_UNSUPPORTED for an
    // unexplained absence too, same convention and same reasoning
    // (VehicleState.mc's own KIND_UNSUPPORTED comment): this app only ever
    // fetches parkingPosition via an explicit `include`, so an absence with
    // no matching error genuinely means "this vehicle doesn't have this".
    function _kindForAbsence(errors as Array?) as String {
        if (errors != null) {
            for (var i = 0; i < errors.size(); i += 1) {
                var entry = errors[i] as Dictionary;
                var errorType = entry.get("type") as String?;
                if (errorType == null) {
                    continue;
                }
                if (errorType.equals("PARKING_POSITION_UNAVAILABLE")) {
                    return VehicleState.KIND_UNAVAILABLE;
                }
                if (errorType.equals("PARKING_POSITION_DISABLED")) {
                    return VehicleState.KIND_DISABLED;
                }
                if (errorType.equals("PARKING_POSITION_UNSUPPORTED")) {
                    return VehicleState.KIND_UNSUPPORTED;
                }
            }
        }
        return VehicleState.KIND_UNSUPPORTED;
    }

    // US-013-style offline path: whatever Cache.mc's own "parkingPosition"
    // key last held (only ever PARKED or IN_MOTION, see Cache.update(),
    // which only writes this key when the raw section was present at all).
    // Absence here is genuinely ambiguous (never fetched vs. once
    // unsupported/disabled/unavailable) so, exactly like StatusView's own
    // _cachedSection, it becomes KIND_UNKNOWN, never KIND_UNSUPPORTED.
    function fromCache() as Section {
        var raw = Cache.section("parkingPosition");
        if (raw == null) {
            return new Section(VehicleState.KIND_UNKNOWN, null, null, null, null, null);
        }
        return new Section(
            VehicleState.KIND_PRESENT, Cache.sectionAge("parkingPosition"),
            raw.get("state") as String?,
            _toDouble(raw.get("latitude")), _toDouble(raw.get("longitude")),
            raw.get("address") as String?
        );
    }

    // US-028: the address, falling back to coordinates when it could not be
    // resolved.
    function displayAddress(section as Section) as String {
        var address = section.address;
        if (address != null && address.length() > 0) {
            return address;
        }
        if (section.hasCoordinates()) {
            var lat = section.latitude as Double;
            var lon = section.longitude as Double;
            return lat.format("%.5f") + ", " + lon.format("%.5f");
        }
        return "—";
    }

    // Numbers decoded from JSON can land as Float, Double, Number or Long
    // depending on the platform's JSON decoder and, for the Cache path, on
    // whatever Storage happened to keep: this is the one conversion point
    // so every caller above gets a plain Double regardless.
    function _toDouble(value as Object?) as Double? {
        if (value == null) {
            return null;
        }
        if (value instanceof Float) {
            return (value as Float).toDouble();
        }
        if (value instanceof Double) {
            return value as Double;
        }
        if (value instanceof Long) {
            return (value as Long).toDouble();
        }
        if (value instanceof Number) {
            return (value as Number).toDouble();
        }
        return null;
    }

}

// Pure geometry and formatting (US-029): no I/O, so every function here is
// exercised directly by tests/LocationTests.mc without touching GPS,
// Storage or the network.
module LocationMath {

    const EARTH_RADIUS_METERS as Double = 6371000.0d;

    // Great-circle (haversine) distance in meters between two WGS-84 points.
    function distanceMeters(lat1 as Double, lon1 as Double, lat2 as Double, lon2 as Double) as Double {
        var phi1 = Math.toRadians(lat1).toDouble();
        var phi2 = Math.toRadians(lat2).toDouble();
        var deltaPhi = Math.toRadians(lat2 - lat1).toDouble();
        var deltaLambda = Math.toRadians(lon2 - lon1).toDouble();

        var sinHalfPhi = Math.sin(deltaPhi / 2.0d).toDouble();
        var sinHalfLambda = Math.sin(deltaLambda / 2.0d).toDouble();
        var cosPhi1 = Math.cos(phi1).toDouble();
        var cosPhi2 = Math.cos(phi2).toDouble();

        var a = (sinHalfPhi * sinHalfPhi) + (cosPhi1 * cosPhi2 * sinHalfLambda * sinHalfLambda);
        var sqrtA = Math.sqrt(a).toDouble();
        var sqrtOneMinusA = Math.sqrt(1.0d - a).toDouble();
        var c = 2.0d * Math.atan2(sqrtA, sqrtOneMinusA).toDouble();

        return EARTH_RADIUS_METERS * c;
    }

    // Initial bearing in degrees [0, 360) from point 1 to point 2, 0 = true
    // north, clockwise.
    function bearingDegrees(lat1 as Double, lon1 as Double, lat2 as Double, lon2 as Double) as Double {
        var phi1 = Math.toRadians(lat1).toDouble();
        var phi2 = Math.toRadians(lat2).toDouble();
        var deltaLambda = Math.toRadians(lon2 - lon1).toDouble();

        var y = Math.sin(deltaLambda).toDouble() * Math.cos(phi2).toDouble();
        var x = (Math.cos(phi1).toDouble() * Math.sin(phi2).toDouble())
            - (Math.sin(phi1).toDouble() * Math.cos(phi2).toDouble() * Math.cos(deltaLambda).toDouble());
        var theta = Math.atan2(y, x).toDouble();

        return normalizeDegrees(Math.toDegrees(theta).toDouble());
    }

    function normalizeDegrees(degrees as Double) as Double {
        var d = degrees;
        while (d < 0.0d) {
            d += 360.0d;
        }
        while (d >= 360.0d) {
            d -= 360.0d;
        }
        return d;
    }

    // The angle (radians, clockwise from "up" on screen) to draw the bearing
    // arrow at. When the device's own compass heading isn't known yet, falls
    // back to drawing the absolute bearing as if north were up: still
    // honest, just not corrected for which way the user happens to be
    // facing (see LocationView._onPosition: heading is Position.Info's own
    // field, distinct from the GPS fix itself).
    function arrowAngleRadians(bearingDegreesToTarget as Double, headingRadians as Double?) as Double {
        var bearingRadians = Math.toRadians(bearingDegreesToTarget).toDouble();
        if (headingRadians == null) {
            return bearingRadians;
        }
        return bearingRadians - (headingRadians as Double);
    }

    // US-029: "the distance in the device's unit system".
    // System.getDeviceSettings().distanceUnits, never a separate app
    // Setting; there is nothing to configure here beyond what the watch
    // already knows.
    function formatDistance(meters as Double, unitSystem as System.UnitsSystem) as String {
        if (unitSystem == System.UNIT_STATUTE) {
            var feet = meters * 3.28084d;
            if (feet < 1000.0d) {
                return feet.toNumber().toString() + " ft";
            }
            var miles = meters / 1609.344d;
            return miles.format("%.1f") + " mi";
        }
        if (meters < 1000.0d) {
            return meters.toNumber().toString() + " m";
        }
        return (meters / 1000.0d).format("%.1f") + " km";
    }

}

// Whether this vehicle has ever, on a live fetch that explicitly requested
// parkingPosition, been told PARKING_POSITION_UNSUPPORTED (US-033: "hides
// the feature for this vehicle"). Persisted in its own Storage key:
// separate from Cache.mc's "vehicleCache", which this task does not own and
// which has no room in its compact projection for a section's error
// classification anyway (see VehicleState.mc's own module comment on
// exactly that gap), so ControlsView's tile can hide itself on a later
// launch without waiting for a fresh fetch first.
module ParkingFeature {

    const STORAGE_KEY = "parkingPositionUnsupported";

    // Only ever called from LocationView's own fetch, which always passes
    // `include=parkingPosition`: see ParkingPosition._kindForAbsence's own
    // comment on why that is what makes KIND_UNSUPPORTED here trustworthy.
    function noteSupportKnown(kind as String) as Void {
        var unsupported = kind.equals(VehicleState.KIND_UNSUPPORTED);
        Storage.setValue(STORAGE_KEY, unsupported as Storage.ValueType);
    }

    // Defaults to false (assume possibly supported) until a live fetch has
    // said otherwise: the same "innocent until proven otherwise" rule
    // VehicleState/ControlTiles already apply to a vehicle's operations[].
    function isKnownUnsupported() as Boolean {
        var stored = Storage.getValue(STORAGE_KEY);
        return stored instanceof Boolean && (stored as Boolean);
    }

    function clear() as Void {
        Storage.deleteValue(STORAGE_KEY);
    }

}

// The last position we actually saw the car PARKED at, kept in its own
// Storage key rather than reusing Cache.mc's "parkingPosition" entry. That
// distinction is the point: Cache.update() unconditionally overwrites its
// own parkingPosition section with whatever the API just said, including
// an IN_MOTION reading with no coordinates at all, which is exactly right
// for Cache's own job (US-013: show the live truth, cached) but would erase
// the one thing US-033 asks THIS screen to keep on hand: where the car was
// last actually parked, for exactly as long as it takes the car to stop
// moving again.
module LastParked {

    const STORAGE_KEY = "lastParkedPosition";

    function record(section as ParkingPosition.Section) as Void {
        if (!section.isParked()) {
            return;
        }
        // Built as a `Dictionary`-typed local first, not an inline literal
        // cast straight `as Storage.ValueType`: the literal's value types
        // here are a poly mix (Double, String?, Number?) and casting that
        // directly confuses the compiler into treating it as a byte-array
        // initializer. An explicit Dictionary annotation sidesteps it (see
        // Cache.mc's own _save(), which stores a Dictionary-typed local the
        // same way, never an inline-cast literal).
        var record = {
            "latitude" => section.latitude,
            "longitude" => section.longitude,
            "address" => section.address,
            "age" => section.age
        } as Dictionary;
        Storage.setValue(STORAGE_KEY, record as Storage.ValueType);
    }

    function get() as ParkingPosition.Section? {
        var stored = Storage.getValue(STORAGE_KEY);
        if (!(stored instanceof Dictionary)) {
            return null;
        }
        var raw = stored as Dictionary;
        return new ParkingPosition.Section(
            VehicleState.KIND_PRESENT, raw.get("age") as Number?, "PARKED",
            raw.get("latitude") as Double?, raw.get("longitude") as Double?, raw.get("address") as String?
        );
    }

    function clear() as Void {
        Storage.deleteValue(STORAGE_KEY);
    }

}

// US-032: saves one Waypoint under a stable name and hands off to the
// system's own navigation via System.exitTo(), which always shows its own
// confirmation dialog and then terminates this app. LocationView.confirmNavigate()
// is the only caller, and only reaches this after the user has said yes to
// this app's OWN warning that the app is about to close.
module CarNavigation {

    const WAYPOINT_NAME = "Skoda Connect Car";

    // Exposed (not folded into _findExisting()) so LocationTests.mc can
    // check the stable-name comparison this module relies on without
    // touching real PersistedContent.
    function isStableWaypoint(name as String) as Boolean {
        return name.equals(WAYPOINT_NAME);
    }

    function start(location as Position.Location) as Void {
        _removeExisting();
        PersistedContent.saveWaypoint(location, { :name => WAYPOINT_NAME });
        var saved = _findExisting();
        if (saved != null) {
            System.exitTo((saved as PersistedContent.Content).toIntent());
        }
    }

    // US-032: replace, never accumulate. PersistedContent has no upsert, so
    // this removes whatever this app previously saved under WAYPOINT_NAME
    // before saving a fresh one. getAppWaypoints() is already scoped to
    // content this app itself created, so this can never touch anything the
    // user saved by hand.
    function _removeExisting() as Void {
        var existing = _findExisting();
        if (existing != null) {
            (existing as PersistedContent.Content).remove();
        }
    }

    function _findExisting() as PersistedContent.Content? {
        var iterator = PersistedContent.getAppWaypoints();
        var item = iterator.next();
        while (item != null) {
            var content = item as PersistedContent.Content;
            if (isStableWaypoint(content.getName())) {
                return content;
            }
            item = iterator.next();
        }
        return null;
    }

}

// The find-my-car screen itself. Reached from ControlsView's own tile (see
// this task's addition to ControlsView._buildTiles()); back leaves it the
// normal, un-remapped way (docs/best-practices: this view never overrides
// onBack()).
class LocationView extends WatchUi.View {

    private var _section as ParkingPosition.Section? = null;
    private var _fetching as Boolean = false;
    private var _lastError as String? = null;
    // US-028's own note says fetch when the user opens this screen, but
    // onShow() re-fires every time a child view (the map, a confirmation,
    // the menu) pops back to this one, and re-spending quota on every one
    // of those would be wasteful. This flag makes the auto-fetch a
    // once-per-visit thing; the menu's own "Refresh" item (see
    // LocationActionMenu below) is how a user asks for a second one.
    private var _hasFetchedOnce as Boolean = false;

    private var _myPosition as Position.Location? = null;
    private var _myAccuracy as Position.Quality = Position.QUALITY_NOT_AVAILABLE;
    private var _myHeading as Double? = null;
    private var _positionEventsActive as Boolean = false;

    function initialize() {
        View.initialize();
    }

    // No resources to load: every draw call below uses a built-in font,
    // same as StatusView/ControlsView.
    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        if (_section == null) {
            _section = ParkingPosition.fromCache();
        }
        _startPositionEvents();
        if (!_hasFetchedOnce) {
            refresh();
        }
    }

    // US-029's hard rule, restated from the task brief: a watch app that
    // leaves GPS running after the screen using it is gone is an explicit
    // battery complaint in Garmin's review guidelines. Symmetrical with
    // _startPositionEvents(): every path that turns events on is matched
    // by exactly this one place turning them off.
    function onHide() as Void {
        _stopPositionEvents();
    }

    // ------------------------------------------------------------ fetching

    function refresh() as Void {
        if (_fetching) {
            return;
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            return;
        }
        if (!Quota.canSpend()) {
            return;
        }
        var settings = getApp().getSettings();
        if (!settings.vinValid || settings.apiKey.length() == 0) {
            return;
        }

        _fetching = true;
        _hasFetchedOnce = true;
        _lastError = null;
        WatchUi.requestUpdate();

        // Only this section: same quota cost as the unfiltered read (see
        // StatusView's own note), and it is also what makes
        // PARKING_POSITION_UNSUPPORTED show up as a real error rather than a
        // silent, ambiguous omission (see ParkingPosition._kindForAbsence).
        ApiClient.getVehicle(settings.vin, "parkingPosition", settings.apiKey, method(:_onVehicleResponse));
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
                    // sections actually present in `vehicle` (its own doc
                    // comment), so a parkingPosition-only fetch can never
                    // clobber charging/status/etc cached by other screens.
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
        _lastError = _shorten(ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text);
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
    // the network, so the bearing arrow tracks the user turning without
    // spending any of the hourly API quota.
    function _onPosition(info as Position.Info) as Void {
        _myPosition = info.position;
        _myAccuracy = info.accuracy;
        var heading = info.heading;
        _myHeading = (heading != null) ? (heading as Float).toDouble() : null;
        WatchUi.requestUpdate();
    }

    // ------------------------------------------------------------- actions

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
            // for this specific area": only for "this build/device
            // supports MapView at all" (checked here); see this task's
            // final report for why that is the best available proxy.
            return;
        }
        var carLocation = new Position.Location({
            :latitude => section.latitude as Double, :longitude => section.longitude as Double, :format => :degrees
        });
        var map = new MapPreviewView(carLocation, _myPosition);
        WatchUi.pushView(map, new MapPreviewDelegate(map), WatchUi.SLIDE_LEFT);
    }

    // US-032: only ever opens the confirmation. CarNavigation.start(): the
    // thing that actually calls System.exitTo(): is reached exclusively
    // through a "yes" on that dialog; see NavigateConfirmDelegate below.
    function confirmNavigate() as Void {
        var section = _section;
        if (section == null || !section.isParked()) {
            return;
        }
        var dialog = new WatchUi.Confirmation(
            "Navigate to the car? This closes this app - starting navigation always exits to the system."
        );
        WatchUi.pushView(
            dialog,
            new NavigateConfirmDelegate(section.latitude as Double, section.longitude as Double),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    // -------------------------------------------------------- rendering
    //
    // Pre-computed by the time onUpdate() runs, see _onVehicleResponse()/
    // _onPosition() above, so onUpdate() below only ever draws (see
    // docs/best-practices, "Pre-compute, then draw").

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 12, Graphics.FONT_SMALL, "FIND MY CAR", Graphics.TEXT_JUSTIFY_CENTER);
        _drawStatusLine(dc, centerX);

        var section = _section;
        if (section == null) {
            section = ParkingPosition.fromCache();
            _section = section;
        }

        if (section.kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            _drawMessage(dc, centerX, "Not supported\nby this car");
        } else if (section.kind.equals(VehicleState.KIND_DISABLED)) {
            _drawMessage(dc, centerX, "Parking position is\nswitched off for this car");
        } else if (section.kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            _drawMessage(dc, centerX, "Temporarily unavailable\nMENU to try again");
            _drawLastKnownParked(dc, centerX);
        } else if (section.kind.equals(VehicleState.KIND_UNKNOWN)) {
            _drawMessage(dc, centerX, "No data yet\nMENU to refresh");
        } else if (section.state != null && (section.state as String).equals("IN_MOTION")) {
            _drawMessage(dc, centerX, "Car is moving");
            _drawLastKnownParked(dc, centerX);
        } else {
            _drawParked(dc, centerX, section);
        }

        _drawBottomHint(dc, centerX, height, section);
    }

    private function _drawStatusLine(dc as Dc, centerX as Number) as Void {
        if (!(System.getDeviceSettings().phoneConnected)) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 30, Graphics.FONT_XTINY, "Phone not connected", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (_fetching) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 30, Graphics.FONT_XTINY, "Refreshing...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var error = _lastError;
        if (error != null) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 30, Graphics.FONT_XTINY, error, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function _drawMessage(dc as Dc, centerX as Number, text as String) as Void {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 110, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // US-033: the one place both IN_MOTION and _UNAVAILABLE reach for "where
    // the car was last actually parked", see the LastParked module comment
    // for why this cannot simply be Cache.section("parkingPosition").
    private function _drawLastKnownParked(dc as Dc, centerX as Number) as Void {
        var last = LastParked.get();
        if (last == null) {
            return;
        }
        var lastSection = last as ParkingPosition.Section;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 150, Graphics.FONT_XTINY, "Last parked:", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 168, Graphics.FONT_XTINY, _shorten(ParkingPosition.displayAddress(lastSection)), Graphics.TEXT_JUSTIFY_CENTER);
        _drawAge(dc, centerX, 210, lastSection.age);
    }

    private function _drawParked(dc as Dc, centerX as Number, section as ParkingPosition.Section) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 56, Graphics.FONT_XTINY, _shorten(ParkingPosition.displayAddress(section)), Graphics.TEXT_JUSTIFY_CENTER);

        if (!section.hasCoordinates()) {
            // PARKED always carries gpsCoordinates per the schema, but never
            // trust that blindly: draw nothing further rather than crash.
            _drawAge(dc, centerX, 210, section.age);
            return;
        }

        var myPosition = _myPosition;
        if (myPosition == null || _myAccuracy == Position.QUALITY_NOT_AVAILABLE) {
            // US-029: say we're acquiring a fix rather than draw a wrong
            // bearing.
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL, "Acquiring GPS\nposition...", Graphics.TEXT_JUSTIFY_CENTER);
            _drawAge(dc, centerX, 210, section.age);
            return;
        }

        var myDegrees = (myPosition as Position.Location).toDegrees();
        var myLat = myDegrees[0];
        var myLon = myDegrees[1];
        var carLat = section.latitude as Double;
        var carLon = section.longitude as Double;

        var distance = LocationMath.distanceMeters(myLat, myLon, carLat, carLon);
        var bearing = LocationMath.bearingDegrees(myLat, myLon, carLat, carLon);
        var unitSystem = System.getDeviceSettings().distanceUnits;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 108, Graphics.FONT_NUMBER_MEDIUM, LocationMath.formatDistance(distance, unitSystem), Graphics.TEXT_JUSTIFY_CENTER);

        // US-029: rotates with _myHeading, updated purely from
        // _onPosition(): no re-fetch needed for the arrow to track a turn.
        var angle = LocationMath.arrowAngleRadians(bearing, _myHeading);
        _drawBearingArrow(dc, centerX, 172, 28, angle);

        _drawAge(dc, centerX, 210, section.age);
    }

    private function _drawBearingArrow(dc as Dc, cx as Number, cy as Number, radius as Number, angleRadians as Double) as Void {
        var sinA = Math.sin(angleRadians).toDouble();
        var cosA = Math.cos(angleRadians).toDouble();
        var tipX = cx + (radius * sinA);
        var tipY = cy - (radius * cosA);

        var backRadius = radius * 0.45;
        var spread = 2.5d; // radians either side of the tip: a wide, legible kite shape
        var leftAngle = angleRadians + spread;
        var rightAngle = angleRadians - spread;
        var leftX = cx + (backRadius * Math.sin(leftAngle).toDouble());
        var leftY = cy - (backRadius * Math.cos(leftAngle).toDouble());
        var rightX = cx + (backRadius * Math.sin(rightAngle).toDouble());
        var rightY = cy - (backRadius * Math.cos(rightAngle).toDouble());

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius + 4);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [tipX.toNumber(), tipY.toNumber()] as Graphics.Point2D,
            [leftX.toNumber(), leftY.toNumber()] as Graphics.Point2D,
            [cx, cy] as Graphics.Point2D,
            [rightX.toNumber(), rightY.toNumber()] as Graphics.Point2D
        ] as Array<Graphics.Point2D>);
    }

    private function _drawBottomHint(dc as Dc, centerX as Number, height as Number, section as ParkingPosition.Section) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var hint = "MENU for options";
        if (section.isParked()) {
            hint = "SELECT map - MENU navigate";
        }
        dc.drawText(centerX, height - 20, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // US-009-style age line, duplicated from StatusView's own (small, and
    // this task doesn't own StatusView.mc to reuse it from, see this
    // task's file-ownership rules).
    private function _drawAge(dc as Dc, centerX as Number, y as Number, age as Number?) as Void {
        if (age == null) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "No data", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var ageSeconds = Time.now().value() - age;
        if (ageSeconds < 0) {
            ageSeconds = 0;
        }
        var stale = ageSeconds > 3600;
        dc.setColor(stale ? Graphics.COLOR_RED : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_XTINY, (stale ? "! " : "") + _ageText(ageSeconds), Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _ageText(seconds as Number) as String {
        if (seconds < 60) {
            return "Updated just now";
        }
        var minutes = seconds / 60;
        if (minutes < 60) {
            return minutes.toString() + " min ago";
        }
        var hours = minutes / 60;
        if (hours < 24) {
            var remainderMinutes = minutes - (hours * 60);
            return hours.toString() + "h " + remainderMinutes.toString() + "m ago";
        }
        var days = hours / 24;
        return days.toString() + "d ago";
    }

    private function _shorten(text as String) as String {
        if (text.length() > 40) {
            return text.substring(0, 40) as String;
        }
        return text;
    }

}

// BehaviorDelegate, never InputDelegate (docs/best-practices). Never
// overrides onBack(): back leaves this screen the normal way.
class LocationDelegate extends WatchUi.BehaviorDelegate {

    // Weak: this delegate is owned by the view it acts on (pushed
    // alongside it), see docs/best-practices, "Break reference cycles with
    // weak()".
    private var _view as WeakReference;

    function initialize(view as LocationView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    // US-030: SELECT is the direct, single-press way to ask for the map.
    // same "SELECT is the primary/direct action" convention StatusView and
    // ControlsView already use.
    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.openMap();
        }
        return true;
    }

    // US-032/refresh: the secondary actions, same MENU convention the
    // onboarding screens already use (OnboardingDelegate.onMenu()).
    function onMenu() as Boolean {
        var view = _resolve();
        if (view != null) {
            LocationActionMenu.push(view);
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

// The MENU escape hatch's two items (US-032's Navigate, plus a manual
// Refresh): split into its own Menu2 module the same way
// OnboardingActionMenu.mc is, rather than built inline in the delegate.
module LocationActionMenu {

    function push(view as LocationView) as Void {
        var menu = new WatchUi.Menu2({ :title => "Find my car" });
        menu.addItem(new WatchUi.MenuItem("Navigate to car", null, :navigate, null));
        menu.addItem(new WatchUi.MenuItem("Refresh", null, :refresh, null));
        WatchUi.pushView(menu, new LocationActionMenuDelegate(view), WatchUi.SLIDE_UP);
    }

}

class LocationActionMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WeakReference;

    function initialize(view as LocationView) {
        Menu2InputDelegate.initialize();
        _view = view.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var view = _resolve();
        if (view == null) {
            return;
        }
        var id = item.getId();
        if (id == :navigate) {
            view.confirmNavigate();
            return;
        }
        if (id == :refresh) {
            view.refresh();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    private function _resolve() as LocationView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as LocationView?;
    }

}

// US-032: fires only on an explicit "yes". This IS the "warn the user
// first that this closes the app" the task calls for; CarNavigation.start()
// is never reached any other way.
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
