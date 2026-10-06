import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

// Unit tests for source/ui/LocationView.mc (US-028..US-033): the pure
// geometry (LocationMath), the parkingPosition parser and its four edge
// cases (ParkingPosition), and the small Storage-backed modules
// (ParkingFeature, LastParked) that let this screen behave correctly across
// restarts without reaching into Cache.mc, see LocationView.mc's own module
// comments for why each of these exists separately from task 6/4's own
// model code.
//
// Nothing here touches GPS, the network or PersistedContent's waypoint
// APIs: LocationMath and ParkingPosition are pure (no Storage, no I/O), and
// the Storage-backed modules are exercised the same way QuotaTests.mc
// exercises Quota.mc: clear(), then round-trip.
module LocationTests {

    // ------------------------------------------------------------ helpers

    function _closeEnough(actual as Double, expected as Double, tolerance as Double) as Boolean {
        var diff = actual - expected;
        if (diff < 0.0d) {
            diff = -diff;
        }
        return diff <= tolerance;
    }

    // -------------------------------------------------------- LocationMath

    (:test)
    function bearingDueEastIsNinetyDegrees(logger as Logger) as Boolean {
        var bearing = LocationMath.bearingDegrees(0.0d, 0.0d, 0.0d, 1.0d);
        if (!_closeEnough(bearing, 90.0d, 0.5d)) {
            logger.error("expected ~90 degrees due east, got " + bearing.toString());
            return false;
        }
        return true;
    }

    (:test)
    function bearingDueNorthIsZeroDegrees(logger as Logger) as Boolean {
        var bearing = LocationMath.bearingDegrees(0.0d, 0.0d, 1.0d, 0.0d);
        if (!_closeEnough(bearing, 0.0d, 0.5d)) {
            logger.error("expected ~0 degrees due north, got " + bearing.toString());
            return false;
        }
        return true;
    }

    (:test)
    function bearingDueSouthIsOneEightyDegrees(logger as Logger) as Boolean {
        var bearing = LocationMath.bearingDegrees(0.0d, 0.0d, -1.0d, 0.0d);
        if (!_closeEnough(bearing, 180.0d, 0.5d)) {
            logger.error("expected ~180 degrees due south, got " + bearing.toString());
            return false;
        }
        return true;
    }

    (:test)
    function bearingDueWestIsTwoSeventyDegrees(logger as Logger) as Boolean {
        var bearing = LocationMath.bearingDegrees(0.0d, 0.0d, 0.0d, -1.0d);
        if (!_closeEnough(bearing, 270.0d, 0.5d)) {
            logger.error("expected ~270 degrees due west, got " + bearing.toString());
            return false;
        }
        return true;
    }

    (:test)
    function normalizeDegreesWrapsIntoZeroToThreeSixty(logger as Logger) as Boolean {
        if (!_closeEnough(LocationMath.normalizeDegrees(-30.0d), 330.0d, 0.001d)) {
            logger.error("negative degrees not wrapped correctly");
            return false;
        }
        if (!_closeEnough(LocationMath.normalizeDegrees(370.0d), 10.0d, 0.001d)) {
            logger.error("over-360 degrees not wrapped correctly");
            return false;
        }
        return true;
    }

    // One degree of longitude at the equator is ~111.32 km: a well-known
    // reference value for sanity-checking the haversine formula without
    // hand-deriving a second implementation.
    (:test)
    function distanceOneDegreeLongitudeAtEquator(logger as Logger) as Boolean {
        var meters = LocationMath.distanceMeters(0.0d, 0.0d, 0.0d, 1.0d);
        if (!_closeEnough(meters, 111320.0d, 500.0d)) {
            logger.error("expected ~111320 m, got " + meters.toString());
            return false;
        }
        return true;
    }

    (:test)
    function distanceBetweenIdenticalPointsIsZero(logger as Logger) as Boolean {
        var meters = LocationMath.distanceMeters(52.100000d, 5.100000d, 52.100000d, 5.100000d);
        if (!_closeEnough(meters, 0.0d, 0.01d)) {
            logger.error("expected 0 m between identical points, got " + meters.toString());
            return false;
        }
        return true;
    }

    (:test)
    function formatDistanceMetricUnderAKilometer(logger as Logger) as Boolean {
        var text = LocationMath.formatDistance(500.0d, System.UNIT_METRIC);
        if (!text.equals("500 m")) {
            logger.error("expected '500 m', got '" + text + "'");
            return false;
        }
        return true;
    }

    (:test)
    function formatDistanceMetricOverAKilometer(logger as Logger) as Boolean {
        var text = LocationMath.formatDistance(1500.0d, System.UNIT_METRIC);
        if (!text.equals("1.5 km")) {
            logger.error("expected '1.5 km', got '" + text + "'");
            return false;
        }
        return true;
    }

    (:test)
    function formatDistanceStatuteUnderAMile(logger as Logger) as Boolean {
        var text = LocationMath.formatDistance(100.0d, System.UNIT_STATUTE);
        if (!text.equals("328 ft")) {
            logger.error("expected '328 ft', got '" + text + "'");
            return false;
        }
        return true;
    }

    (:test)
    function formatDistanceStatuteOverAMile(logger as Logger) as Boolean {
        var text = LocationMath.formatDistance(5000.0d, System.UNIT_STATUTE);
        if (!text.equals("3.1 mi")) {
            logger.error("expected '3.1 mi', got '" + text + "'");
            return false;
        }
        return true;
    }

    // US-029: "the arrow updates as I turn". Turning changes the device's
    // own heading, not the bearing to the car, so the drawn angle must move
    // by exactly the heading delta.
    (:test)
    function arrowAngleAccountsForDeviceHeading(logger as Logger) as Boolean {
        var facingNorth = LocationMath.arrowAngleRadians(90.0d, 0.0d);
        var facingEast = LocationMath.arrowAngleRadians(90.0d, Math.toRadians(90.0d).toDouble());
        // Facing north with the car due east: arrow points toward "screen
        // east" (90 degrees clockwise from up). Facing east with the car
        // still due east: the car is now straight ahead (0 = up).
        if (!_closeEnough(facingNorth, Math.toRadians(90.0d).toDouble(), 0.01d)) {
            logger.error("expected arrow at ~90 degrees clockwise when facing north");
            return false;
        }
        if (!_closeEnough(facingEast, 0.0d, 0.01d)) {
            logger.error("expected arrow pointing straight up when facing the car directly");
            return false;
        }
        return true;
    }

    (:test)
    function arrowAngleFallsBackToAbsoluteBearingWithoutHeading(logger as Logger) as Boolean {
        var angle = LocationMath.arrowAngleRadians(45.0d, null);
        if (!_closeEnough(angle, Math.toRadians(45.0d).toDouble(), 0.01d)) {
            logger.error("expected the raw bearing when heading is unknown");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ ParkingPosition

    (:test)
    function parkedWithAddressIsPresentAndParked(logger as Logger) as Boolean {
        var vehicle = {
            "parkingPosition" => {
                "state" => "PARKED",
                "gpsCoordinates" => { "latitude" => 52.100000, "longitude" => 5.100000 },
                "formattedAddress" => "Testlaan 1, 1000 AA Teststad, Netherlands"
            }
        };
        var section = ParkingPosition.parse(vehicle, null, 1000);

        if (!section.isPresent() || !section.isParked()) {
            logger.error("expected a present, parked section");
            return false;
        }
        if (section.address == null || !(section.address as String).equals("Testlaan 1, 1000 AA Teststad, Netherlands")) {
            logger.error("formattedAddress not carried through");
            return false;
        }
        if (!ParkingPosition.displayAddress(section).equals("Testlaan 1, 1000 AA Teststad, Netherlands")) {
            logger.error("displayAddress must prefer the formatted address when present");
            return false;
        }
        if (section.age != 1000) {
            logger.error("age must be the 'now' passed to parse(), parkingPosition has no carCapturedTimestamp of its own");
            return false;
        }
        return true;
    }

    // US-028: "given the address could not be resolved, then coordinates are
    // shown instead."
    (:test)
    function parkedWithoutAddressFallsBackToCoordinates(logger as Logger) as Boolean {
        var vehicle = {
            "parkingPosition" => {
                "state" => "PARKED",
                "gpsCoordinates" => { "latitude" => 52.100000, "longitude" => 5.100000 }
            }
        };
        var section = ParkingPosition.parse(vehicle, null, 1000);

        if (section.address != null) {
            logger.error("expected no formattedAddress in this fixture");
            return false;
        }
        var displayed = ParkingPosition.displayAddress(section);
        if (!displayed.equals("52.10000, 5.10000")) {
            logger.error("expected coordinates formatted to 5 decimals, got '" + displayed + "'");
            return false;
        }
        return true;
    }

    // US-033: IN_MOTION carries no coordinates at all.
    (:test)
    function inMotionHasNoCoordinates(logger as Logger) as Boolean {
        var vehicle = { "parkingPosition" => { "state" => "IN_MOTION" } };
        var section = ParkingPosition.parse(vehicle, null, 1000);

        if (!section.isPresent()) {
            logger.error("IN_MOTION is still a PRESENT section, just without coordinates");
            return false;
        }
        if (section.hasCoordinates()) {
            logger.error("IN_MOTION must never carry coordinates");
            return false;
        }
        if (section.isParked()) {
            logger.error("IN_MOTION must never be treated as an actionable parked position");
            return false;
        }
        if (section.state == null || !(section.state as String).equals("IN_MOTION")) {
            logger.error("state must be carried through verbatim");
            return false;
        }
        return true;
    }

    (:test)
    function unsupportedErrorHidesTheSection(logger as Logger) as Boolean {
        var vehicle = {};
        var errors = [ { "type" => "PARKING_POSITION_UNSUPPORTED" } ];
        var section = ParkingPosition.parse(vehicle, errors, 1000);

        if (!section.kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            logger.error("expected KIND_UNSUPPORTED");
            return false;
        }
        return true;
    }

    (:test)
    function disabledErrorIsDistinctFromUnsupported(logger as Logger) as Boolean {
        var vehicle = {};
        var errors = [ { "type" => "PARKING_POSITION_DISABLED" } ];
        var section = ParkingPosition.parse(vehicle, errors, 1000);

        if (!section.kind.equals(VehicleState.KIND_DISABLED)) {
            logger.error("expected KIND_DISABLED");
            return false;
        }
        return true;
    }

    (:test)
    function unavailableErrorIsDistinctFromUnsupported(logger as Logger) as Boolean {
        var vehicle = {};
        var errors = [ { "type" => "PARKING_POSITION_UNAVAILABLE" } ];
        var section = ParkingPosition.parse(vehicle, errors, 1000);

        if (!section.kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            logger.error("expected KIND_UNAVAILABLE");
            return false;
        }
        return true;
    }

    // An absence with no matching error at all falls back to UNSUPPORTED:
    // the same convention VehicleState.mc uses for every other section, and
    // trustworthy here specifically because LocationView always fetches
    // with an explicit `include=parkingPosition` (see
    // ParkingPosition._kindForAbsence's own comment).
    (:test)
    function unexplainedAbsenceFallsBackToUnsupported(logger as Logger) as Boolean {
        var section = ParkingPosition.parse({}, null, 1000);
        if (!section.kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            logger.error("expected KIND_UNSUPPORTED for an unexplained absence");
            return false;
        }
        return true;
    }

    (:test)
    function displayAddressFallsBackToEmDashWithNeitherAddressNorCoordinates(logger as Logger) as Boolean {
        var section = ParkingPosition.parse({ "parkingPosition" => { "state" => "IN_MOTION" } }, null, 1000);
        if (!ParkingPosition.displayAddress(section).equals("—")) {
            logger.error("expected an em dash when there is nothing to show at all");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ ParkingFeature

    (:test)
    function parkingFeatureDefaultsToNotKnownUnsupported(logger as Logger) as Boolean {
        ParkingFeature.clear();
        if (ParkingFeature.isKnownUnsupported()) {
            logger.error("must assume possibly supported before any live fetch has said otherwise");
            return false;
        }
        return true;
    }

    (:test)
    function parkingFeatureRecordsUnsupportedAndSurvivesAReload(logger as Logger) as Boolean {
        ParkingFeature.clear();
        ParkingFeature.noteSupportKnown(VehicleState.KIND_UNSUPPORTED);
        if (!ParkingFeature.isKnownUnsupported()) {
            logger.error("KIND_UNSUPPORTED must be remembered");
            return false;
        }
        return true;
    }

    // Only genuine UNSUPPORTED hides the feature (US-033): DISABLED and
    // UNAVAILABLE are temporary states the user can still open the screen
    // to read about.
    (:test)
    function parkingFeatureIgnoresDisabledAndUnavailable(logger as Logger) as Boolean {
        ParkingFeature.clear();
        ParkingFeature.noteSupportKnown(VehicleState.KIND_DISABLED);
        if (ParkingFeature.isKnownUnsupported()) {
            logger.error("DISABLED must not hide the feature");
            return false;
        }
        ParkingFeature.noteSupportKnown(VehicleState.KIND_UNAVAILABLE);
        if (ParkingFeature.isKnownUnsupported()) {
            logger.error("UNAVAILABLE must not hide the feature");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ LastParked

    (:test)
    function lastParkedRecordsOnlyAnActionableParkedSection(logger as Logger) as Boolean {
        LastParked.clear();
        var inMotion = ParkingPosition.parse({ "parkingPosition" => { "state" => "IN_MOTION" } }, null, 500);
        LastParked.record(inMotion);
        if (LastParked.get() != null) {
            logger.error("IN_MOTION must never overwrite the last known parked position");
            return false;
        }
        return true;
    }

    (:test)
    function lastParkedSurvivesAReloadAndSurvivesALaterInMotionReading(logger as Logger) as Boolean {
        LastParked.clear();
        var parked = ParkingPosition.parse({
            "parkingPosition" => {
                "state" => "PARKED",
                "gpsCoordinates" => { "latitude" => 52.100000, "longitude" => 5.100000 },
                "formattedAddress" => "Testlaan 1, 1000 AA Teststad, Netherlands"
            }
        }, null, 500);
        LastParked.record(parked);

        var stored = LastParked.get();
        if (stored == null) {
            logger.error("a parked reading must be persisted");
            return false;
        }
        if (!(stored as ParkingPosition.Section).isParked()) {
            logger.error("the stored fallback must itself read as parked");
            return false;
        }

        // US-033's whole point: a later IN_MOTION reading must not erase it.
        var inMotion = ParkingPosition.parse({ "parkingPosition" => { "state" => "IN_MOTION" } }, null, 900);
        LastParked.record(inMotion);
        var stillStored = LastParked.get();
        if (stillStored == null || !(stillStored as ParkingPosition.Section).isParked()) {
            logger.error("the last known parked position must survive a later IN_MOTION reading");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ CarNavigation

    (:test)
    function carNavigationWaypointNameIsStable(logger as Logger) as Boolean {
        if (!CarNavigation.isStableWaypoint(CarNavigation.WAYPOINT_NAME)) {
            logger.error("the module's own constant must match its own stability check");
            return false;
        }
        if (CarNavigation.isStableWaypoint("Some Other Waypoint")) {
            logger.error("an unrelated name must not match");
            return false;
        }
        return true;
    }

}
