import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

// Unit tests for source/model/Parking.mc and the Find my car layout and
// START rule in source/ui/LocationView.mc (US-028..US-033, M4, M7), the
// layout checked on every screen via the GeoTests fixtures: the pure
// geometry (LocationMath), the parkingPosition parser and its four edge
// cases (ParkingPosition), and the small Storage-backed modules
// (ParkingFeature, LastParked) that let this screen behave correctly across
// restarts without reaching into Cache.mc, see Parking.mc's own module
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

    // US-029 + A8: number and unit split for the number font; the examples
    // are the PoC's and the 1.0 strings' ("500 m", "1.5 km", "328 ft",
    // "3.1 mi"), so the thresholds and rounding did not move.
    function _expectParts(logger as Logger, meters as Double, units as System.UnitsSystem,
                          number as String, unit as String) as Boolean {
        var parts = LocationMath.distanceParts(meters, units);
        if (!parts[0].equals(number) || !parts[1].equals(unit)) {
            logger.error("expected '" + number + "'/'" + unit + "', got '" + parts[0] + "'/'" + parts[1] + "'");
            return false;
        }
        if (!Ui.isNumberGlyphs(parts[0])) {
            logger.error("number part '" + parts[0] + "' has glyphs the number font lacks");
            return false;
        }
        return true;
    }

    (:test)
    function distancePartsMetricUnderAKilometer(logger as Logger) as Boolean {
        return _expectParts(logger, 240.0d, System.UNIT_METRIC, "240", "m")
            && _expectParts(logger, 500.0d, System.UNIT_METRIC, "500", "m")
            && _expectParts(logger, 999.9d, System.UNIT_METRIC, "999", "m");
    }

    (:test)
    function distancePartsMetricOverAKilometer(logger as Logger) as Boolean {
        return _expectParts(logger, 1000.0d, System.UNIT_METRIC, "1.0", "km")
            && _expectParts(logger, 1200.0d, System.UNIT_METRIC, "1.2", "km")
            && _expectParts(logger, 1500.0d, System.UNIT_METRIC, "1.5", "km");
    }

    (:test)
    function distancePartsStatuteUnderAThousandFeet(logger as Logger) as Boolean {
        return _expectParts(logger, 100.0d, System.UNIT_STATUTE, "328", "ft")
            && _expectParts(logger, 244.0d, System.UNIT_STATUTE, "800", "ft");
    }

    (:test)
    function distancePartsStatuteInMiles(logger as Logger) as Boolean {
        return _expectParts(logger, 482.0d, System.UNIT_STATUTE, "0.3", "mi")
            && _expectParts(logger, 5000.0d, System.UNIT_STATUTE, "3.1", "mi");
    }

    // A far-away car must not push the hero into the ring: no decimal from
    // 100 km/mi on (half the globe is "20015 km", five glyphs).
    (:test)
    function distancePartsDropsTheDecimalFromAHundred(logger as Logger) as Boolean {
        return _expectParts(logger, 99940.0d, System.UNIT_METRIC, "99.9", "km")
            && _expectParts(logger, 123456.0d, System.UNIT_METRIC, "123", "km")
            && _expectParts(logger, 20015086.0d, System.UNIT_METRIC, "20015", "km")
            && _expectParts(logger, 200000.0d, System.UNIT_STATUTE, "124", "mi");
    }

    // C5: the address chords inside the ring track are the PoC's [158, 186]
    // at y 46/65 (fēnix 7 Pro xtiny, 19 px), and wider below the centre.
    (:test)
    function addressWidthsMatchThePoc(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var top = FindCarLayout.addressWidths(g, 46, 19);
        var low = FindCarLayout.addressWidths(g, 150, 19);
        if (top[0] != 158 || top[1] != 186) {
            logger.error("expected [158, 186] at y 46, got [" + top[0] + ", " + top[1] + "]");
            return false;
        }
        if (low[0] <= top[0] || low[1] <= top[0]) {
            logger.error("expected wider chords at y 150, got [" + low[0] + ", " + low[1] + "]");
            return false;
        }
        return true;
    }

    // M4: where START shows the menu glyph, the second address line (65 to
    // 84 on a 260 face, level with the glyph at y 76) keeps 4 px clear of
    // it; the first line is above the glyph and keeps its chord.
    (:test)
    function addressKeepsClearOfTheStartGlyph(logger as Logger) as Boolean {
        var w = FindCarLayout.addressWidthsBesideGlyph(GeoTests.fr255(), 46, 19);
        if (w[0] != 158 || w[1] != 168) {
            logger.error("expected [158, 168] beside the START glyph, got [" + w[0] + ", " + w[1] + "]");
            return false;
        }
        return true;
    }

    // The fēnix 7 Pro slots are today's numbers (PoC NF.parked / gps /
    // moving): the screen must not move a pixel there.
    (:test)
    function findCarSlotsOnTheFenixAreToday(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var s = FindCarLayout.slots(g);
        var got = [s.addressTop, s.distanceTop, s.ageTop, FindCarLayout.gpsTop(g, g.fonts.smallH),
                   s.movingHeroTop, s.lastParkedTop, s.lastAddressTop, s.messageCentre, s.lastAgeTop,
                   s.movingHeroSmallTop, s.gpsAgeTop] as Array<Number>;
        var want = [46, 88, 172, 112, 90, 130, 150, 124, 196, 92, 172] as Array<Number>;
        var names = ["address", "distance", "age", "gps", "moving hero", "last parked", "last address",
                     "message centre", "last age", "moving hero small", "gps age"] as Array<String>;
        var ok = true;
        for (var i = 0; i < want.size(); i += 1) {
            if (got[i] != want[i]) {
                logger.error(names[i] + ": expected " + want[i] + ", got " + got[i]);
                ok = false;
            }
        }
        return ok;
    }

    // On every supported screen the blocks stack top to bottom and the
    // moving block's age stays above the status line (M14).
    (:test)
    function findCarSlotsStackOnEveryScreen(logger as Logger) as Boolean {
        var displays = GeoTests.all();
        var ok = true;
        for (var i = 0; i < displays.size(); i += 1) {
            var g = displays[i] as Geo.Display;
            var s = FindCarLayout.slots(g);
            var xt = g.fonts.xtinyH;
            var what = "display " + i + " (" + g.w + "x" + g.h + ")";
            if (!(s.addressTop + 2 * xt < s.distanceTop && s.distanceTop < s.ageTop && s.ageTop + xt <= g.h)) {
                logger.error(what + ": parked stack " + s.addressTop + "/" + s.distanceTop + "/" + s.ageTop);
                ok = false;
            }
            if (!(s.movingHeroTop < s.lastParkedTop && s.lastParkedTop + xt <= s.lastAddressTop
                  && s.lastAddressTop + 2 * xt <= s.lastAgeTop && s.lastAgeTop + xt <= g.h - g.px(g.round ? 29 : 20))) {
                logger.error(what + ": moving stack " + s.movingHeroTop + "/" + s.lastParkedTop + "/"
                             + s.lastAddressTop + "/" + s.lastAgeTop);
                ok = false;
            }
            if (s.gpsAgeTop < s.addressTop + 2 * xt + g.fonts.smallH) {
                logger.error(what + ": gps age " + s.gpsAgeTop + " runs into the GPS line");
                ok = false;
            }
        }
        return ok;
    }

    // Venu X1: the track is the display frame, so the chords follow the
    // rounded rectangle; every block has room and none spans the frame.
    (:test)
    function findCarChordsOnTheRectangle(logger as Logger) as Boolean {
        var g = GeoTests.venux1();
        var s = FindCarLayout.slots(g);
        var xt = g.fonts.xtinyH;
        var tops = [s.addressTop, s.addressTop + xt, s.distanceTop, s.ageTop, s.lastAddressTop, s.messageCentre]
            as Array<Number>;
        var ok = true;
        for (var i = 0; i < tops.size(); i += 1) {
            var t = tops[i] as Number;
            var w = FindCarLayout.chordWidth(g, t, t + xt);
            if (w <= 0 || w >= g.w) {
                logger.error("chord at y " + t + " is " + w + ", want 0 < w < " + g.w);
                ok = false;
            }
        }
        return ok;
    }

    // M4 truth table: the map only when parked on a watch with MapView.
    (:test)
    function startOpensTheMapOnlyWhenParkedWithAMap(logger as Logger) as Boolean {
        var parked = [true, true, false, false] as Array<Boolean>;
        var map = [true, false, true, false] as Array<Boolean>;
        var want = [:map, :list, :list, :list] as Array<Symbol>;
        var ok = true;
        for (var i = 0; i < want.size(); i += 1) {
            var p = parked[i] as Boolean;
            var m = map[i] as Boolean;
            var got = FindCarLogic.startAction(p, m);
            if (got != want[i]) {
                logger.error("parked " + p + ", map " + m + ": expected " + (want[i] as Symbol).toString()
                             + ", got " + got.toString());
                ok = false;
            }
        }
        return ok;
    }

    // M7: the hints name no button (no MENU key on profile C).
    (:test)
    function findCarHintsNameNoButton(logger as Logger) as Boolean {
        var hints = [FindCarLogic.REFRESH_HINT, FindCarLogic.RETRY_HINT] as Array<String>;
        var ok = true;
        for (var i = 0; i < hints.size(); i += 1) {
            var h = hints[i] as String;
            if (h.find("MENU") != null || h.find("START") != null || h.find("menu") == null) {
                logger.error("hint \"" + h + "\" should point at the menu without a button name");
                ok = false;
            }
        }
        if (!FindCarLogic.REFRESH_HINT.equals("Refresh from the menu")
            || !FindCarLogic.RETRY_HINT.equals("Try again from the menu")) {
            logger.error("hint copy changed: " + FindCarLogic.REFRESH_HINT + " / " + FindCarLogic.RETRY_HINT);
            ok = false;
        }
        return ok;
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
