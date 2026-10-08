import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.PersistedContent;
import Toybox.Position;
import Toybox.System;

// The Find my car model (US-028..US-033), moved out of ui/LocationView.mc
// unchanged in WP4 so the view file holds drawing and input only. Pure parts
// are covered by tests/LocationTests.mc.
//
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
        // openMap()/confirmNavigate()/the START hint arc all need, without
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
    // unsupported/disabled/unavailable) so, exactly like StatusModel's
    // cached sections, it becomes KIND_UNKNOWN, never KIND_UNSUPPORTED.
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
    //
    // Split into [number, unit] so the view can draw the digits in a number
    // font and the unit in a text font (A8); the number part only ever holds
    // number-font glyphs. Same thresholds and rounding as the 1.0 string
    // ("240 m", "1.2 km", "800 ft", "0.3 mi"), except that 100 km/mi and up
    // drop the decimal so the hero stays inside the ring.
    function distanceParts(meters as Double, unitSystem as System.UnitsSystem) as [String, String] {
        if (unitSystem == System.UNIT_STATUTE) {
            var feet = meters * 3.28084d;
            if (feet < 1000.0d) {
                return [feet.toNumber().toString(), "ft"];
            }
            return [_large(meters / 1609.344d), "mi"];
        }
        if (meters < 1000.0d) {
            return [meters.toNumber().toString(), "m"];
        }
        return [_large(meters / 1000.0d), "km"];
    }

    function _large(value as Double) as String {
        if (value < 100.0d) {
            return value.format("%.1f");
        }
        return Math.round(value).toNumber().toString();
    }

}

// Whether this vehicle has ever, on a live fetch that explicitly requested
// parkingPosition, been told PARKING_POSITION_UNSUPPORTED (US-033: "hides
// the feature for this vehicle"). Persisted in its own Storage key:
// separate from Cache.mc's "vehicleCache", which this task does not own and
// which has no room in its compact projection for a section's error
// classification anyway (see VehicleState.mc's own module comment on
// exactly that gap), so home's Find my car row can hide itself on a later
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
// confirmation dialog and then terminates this app. NavigateConfirmDelegate
// (ui/LocationView.mc, opened from Find my car and from the map) is the only
// caller, and only reaches this after the user has said yes to this app's OWN
// warning that the app is about to close.
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
