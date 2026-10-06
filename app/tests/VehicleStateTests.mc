import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/model/VehicleState.mc (US-008 through US-015): a
// full response, a partial one carrying errors[], absent optional fields,
// unrecognised enum values, the hybrid dual-engine reading, and per-section
// age. VehicleState.parse() is pure (no Storage, no I/O) so every test just
// builds a fixture Dictionary and checks the projection: no clear()/reset
// dance is needed between tests, unlike Cache's ParserTests.mc.
module VehicleStateTests {

    // Null-safe stringification for error messages only: a value pulled
    // back out of a Dictionary<Object,Object> is typed Object? even when a
    // test knows it isn't null, and -l 3 rejects `.toString()` on that
    // without this guard.
    function _str(value as Object?) as String {
        if (value == null) {
            return "null";
        }
        return value.toString();
    }

    // ----------------------------------------------------------- fixtures

    function _fullVehicle() as Dictionary {
        return {
            "vin" => "TMBMOCKVIN0000017",
            "name" => "Test Vehicle",
            "status" => {
                "overall" => { "doorsLocked" => "YES", "locked" => "YES", "doors" => "CLOSED", "windows" => "CLOSED", "lights" => "OFF", "reliableLockStatus" => "LOCKED" },
                "detail" => { "sunroof" => "UNSUPPORTED", "trunk" => "CLOSED", "bonnet" => "CLOSED" },
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "fuelStatus" => {
                "carType" => "HYBRID",
                "totalRangeInKm" => 436,
                "primaryEngineRange" => { "engineType" => "GASOLINE", "currentFuelLevelInPercent" => 62, "currentSoCInPercent" => 62, "remainingRangeInKm" => 400 },
                "secondaryEngineRange" => { "engineType" => "ELECTRIC", "currentFuelLevelInPercent" => 100, "currentSoCInPercent" => 100, "remainingRangeInKm" => 36 },
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "odometer" => { "mileageInKm" => 123456, "carCapturedTimestamp" => "2021-06-01T12:00:00Z" },
            "airConditioning" => { "state" => "OFF", "carCapturedTimestamp" => "2021-06-01T12:00:00Z" },
            "charging" => {
                "isVehicleInSavedLocation" => false,
                "status" => {
                    "state" => "READY_FOR_CHARGING",
                    "chargeType" => "OFF",
                    "battery" => { "stateOfChargeInPercent" => 100, "remainingCruisingRangeInMeters" => 36000 }
                },
                "settings" => { "availableChargeModes" => [] },
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "operations" => [
                { "name" => "startCharging" },
                { "name" => "stopCharging" },
                { "name" => "setChargeMode" }
            ]
        };
    }

    // -------------------------------------------------------------- tests

    // US-008/US-009/US-010: a full response projects every section as
    // PRESENT, with its own age, and carries the plain lock/door/window
    // fields through untouched.
    (:test)
    function fullResponseIsProjectedCompletely(logger as Logger) as Boolean {
        var state = VehicleState.parse(_fullVehicle(), null);

        if (state.vin == null || !(state.vin as String).equals("TMBMOCKVIN0000017")) {
            logger.error("vin not projected");
            return false;
        }
        if (state.name == null || !(state.name as String).equals("Test Vehicle")) {
            logger.error("name not projected");
            return false;
        }

        if (!state.status.isPresent()) {
            logger.error("status must be present");
            return false;
        }
        if (!(state.status.values.get("doorsLocked") as String).equals("YES")) {
            logger.error("status.doorsLocked not projected");
            return false;
        }
        if (!(state.status.values.get("sunroof") as String).equals("UNSUPPORTED")) {
            logger.error("status.sunroof must be carried through verbatim, including UNSUPPORTED");
            return false;
        }

        if (!state.charging.isPresent()) {
            logger.error("charging must be present");
            return false;
        }
        if (state.charging.values.get("batterySocPercent") != 100) {
            logger.error("charging.batterySocPercent not projected");
            return false;
        }

        if (!state.odometer.isPresent() || state.odometer.values.get("mileageKm") != 123456) {
            logger.error("odometer not projected");
            return false;
        }

        if (!state.airConditioning.isPresent() || !(state.airConditioning.values.get("state") as String).equals("OFF")) {
            logger.error("airConditioning not projected");
            return false;
        }

        if (!state.hasOperation("startCharging") || !state.hasOperation("setChargeMode")) {
            logger.error("a listed operation must be reported as available");
            return false;
        }
        if (state.hasOperation("startAirConditioning")) {
            logger.error("an operation not in operations[] must not be reported as available");
            return false;
        }

        // "2021-06-01T12:00:00Z" is a fixed, known instant. Every section
        // shares this fixture's timestamp, so every section's age must
        // equal exactly its epoch value, independently derived per section
        // (US-009's "not one global figure").
        var expectedAge = 1622548800;
        if (state.status.age != expectedAge) {
            logger.error("status age wrong: " + (state.status.age != null ? (state.status.age as Number).toString() : "null"));
            return false;
        }
        if (state.charging.age != expectedAge) {
            logger.error("charging age wrong");
            return false;
        }
        if (state.fuelStatus.age != expectedAge) {
            logger.error("fuelStatus age wrong");
            return false;
        }
        if (state.odometer.age != expectedAge) {
            logger.error("odometer age wrong");
            return false;
        }
        if (state.airConditioning.age != expectedAge) {
            logger.error("airConditioning age wrong");
            return false;
        }
        return true;
    }

    // The field test's central finding, reproduced directly: airConditioning
    // 17 hours old while everything else is 12–13 minutes old must show up
    // as genuinely different ages, not be smoothed into one figure.
    (:test)
    function perSectionAgeDivergesIndependently(logger as Logger) as Boolean {
        var vehicle = _fullVehicle();
        var ac = vehicle.get("airConditioning") as Dictionary;
        ac.put("carCapturedTimestamp", "2021-05-31T19:00:00Z"); // 17h before the other sections' 12:00

        var state = VehicleState.parse(vehicle, null);

        var freshAge = state.status.age as Number;
        var staleAge = state.airConditioning.age as Number;
        var diffHours = (staleAge - freshAge).abs() / 3600.0;
        if (diffHours < 16.9 || diffHours > 17.1) {
            logger.error("airConditioning age must diverge from the other sections by ~17h, got " + diffHours.toString() + "h");
            return false;
        }
        return true;
    }

    // US-015: a 200 with errors[] populated is not a failure. Sections
    // present in the body are still projected; sections explained by
    // errors[] get the matching kind and keep no stale values (US-013).
    (:test)
    function partialResponseWithErrorsRendersEverythingPresent(logger as Logger) as Boolean {
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017",
            "status" => {
                "overall" => { "doorsLocked" => "NO", "locked" => "NO", "doors" => "OPEN", "windows" => "CLOSED", "lights" => "OFF" },
                "detail" => { "sunroof" => "UNSUPPORTED", "trunk" => "CLOSED", "bonnet" => "CLOSED" },
                "carCapturedTimestamp" => "2021-06-01T13:00:00Z"
            }
            // charging and parkingPosition omitted, as the mock's
            // "partial-data" scenario does, each explained below.
        };
        var errors = [
            { "type" => "CHARGING_UNAVAILABLE", "description" => "Charging status could not be retrieved from the vehicle." },
            { "type" => "PARKING_POSITION_DISABLED", "description" => "Parking position is supported, but currently disabled." }
        ];

        var state = VehicleState.parse(vehicle, errors);

        if (!state.status.isPresent()) {
            logger.error("the section present in the response must still be projected");
            return false;
        }
        if (!state.charging.kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            logger.error("charging must be marked unavailable, not hidden or treated as failure");
            return false;
        }
        if (state.charging.age != null) {
            logger.error("an unavailable section must carry no age: never a stale one");
            return false;
        }
        if (state.charging.values.get("batterySocPercent") != null) {
            logger.error("an unavailable section must carry no values: never a stale one");
            return false;
        }
        // fuelStatus/odometer/airConditioning: absent, no matching error.
        // US-014's "*_UNSUPPORTED errors are only reported when explicitly
        // requested" case, so this must resolve the same way an explicit
        // UNSUPPORTED does (hidden permanently), not crash or become
        // UNAVAILABLE.
        if (!state.fuelStatus.kind.equals(VehicleState.KIND_UNSUPPORTED)) {
            logger.error("a section absent with no matching error must resolve to unsupported");
            return false;
        }
        return true;
    }

    // US-014: DISABLED is visibly different from UNSUPPORTED/UNAVAILABLE.
    (:test)
    function disabledSectionIsDistinguishedFromUnsupportedAndUnavailable(logger as Logger) as Boolean {
        var vehicle = { "vin" => "TMBMOCKVIN0000017" };
        var errors = [
            { "type" => "FUEL_STATUS_DISABLED", "description" => "Fuel status is currently disabled." }
        ];
        var state = VehicleState.parse(vehicle, errors);
        if (!state.fuelStatus.kind.equals(VehicleState.KIND_DISABLED)) {
            logger.error("FUEL_STATUS_DISABLED must map to KIND_DISABLED, not UNSUPPORTED or UNAVAILABLE");
            return false;
        }
        return true;
    }

    // US-014: operations absent entirely (OPERATIONS_UNAVAILABLE, or simply
    // not requested) must be permissive: show every action.
    (:test)
    function absentOperationsIsPermissive(logger as Logger) as Boolean {
        var vehicle = { "vin" => "TMBMOCKVIN0000017" };
        var state = VehicleState.parse(vehicle, [{ "type" => "OPERATIONS_UNAVAILABLE", "description" => "n/a" }]);
        if (state.operations != null) {
            logger.error("operations must stay null when the response could not determine them");
            return false;
        }
        if (!state.hasOperation("startCharging")) {
            logger.error("with operations unknown, every operation must be reported as available");
            return false;
        }
        return true;
    }

    // Absent optional fields: an in-motion vehicle's status section can be
    // present with only a subset of its own fields populated (this mirrors
    // "our reference vehicle omits licensePlate entirely and returns only
    // bonnet, sunroof and trunk under status.detail" from the task brief).
    (:test)
    function absentOptionalFieldsAreTolerated(logger as Logger) as Boolean {
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017"
            // No licensePlate, no status, no charging, no fuelStatus, no
            // odometer, no airConditioning, no operations at all.
        };
        var state = VehicleState.parse(vehicle, null);

        if (state.status.isPresent() || state.charging.isPresent() || state.fuelStatus.isPresent()
                || state.odometer.isPresent() || state.airConditioning.isPresent()) {
            logger.error("a section absent from the body must never be reported as present");
            return false;
        }
        if (state.status.age != null || state.status.values.size() != 0) {
            logger.error("an absent section must carry no age and no values, not zeros or nulls-in-a-Dictionary");
            return false;
        }
        return true;
    }

    // Unrecognised enum values: openapi.json documents that new values may
    // appear over time and clients "must tolerate values they do not
    // recognize": the parser must pass an unknown value through as-is.
    (:test)
    function unrecognisedEnumValuesPassThrough(logger as Logger) as Boolean {
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017",
            "status" => {
                "overall" => { "doorsLocked" => "PARTIALLY_SECURED", "locked" => "YES", "doors" => "CLOSED", "windows" => "CLOSED", "lights" => "OFF" },
                "detail" => { "sunroof" => "UNSUPPORTED", "trunk" => "CLOSED", "bonnet" => "CLOSED" }
            },
            "charging" => {
                "isVehicleInSavedLocation" => false,
                "status" => { "state" => "PRECONDITIONING_BATTERY" }
            },
            "airConditioning" => { "state" => "DEFROSTING" }
        };
        var state = VehicleState.parse(vehicle, null);

        if (!(state.status.values.get("doorsLocked") as String).equals("PARTIALLY_SECURED")) {
            logger.error("unrecognised status.doorsLocked must pass through unchanged");
            return false;
        }
        if (!(state.charging.values.get("state") as String).equals("PRECONDITIONING_BATTERY")) {
            logger.error("unrecognised charging.state must pass through unchanged");
            return false;
        }
        if (!(state.airConditioning.values.get("state") as String).equals("DEFROSTING")) {
            logger.error("unrecognised airConditioning.state must pass through unchanged");
            return false;
        }
        return true;
    }

    // US-011 / the task's central hybrid warning: the API fills BOTH
    // currentFuelLevelInPercent and currentSoCInPercent for a petrol engine
    // with the same number (62 on the measured reference car): reading the
    // wrong field for the wrong engine gives a plausible but meaningless
    // value, so this pins down that primary (GASOLINE) reads
    // currentFuelLevelInPercent and secondary (ELECTRIC) reads
    // currentSoCInPercent, keyed off each engine's OWN engineType.
    (:test)
    function hybridDualEngineReadsTheCorrectPercentField(logger as Logger) as Boolean {
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017",
            "fuelStatus" => {
                "carType" => "HYBRID",
                "totalRangeInKm" => 436,
                "primaryEngineRange" => { "engineType" => "GASOLINE", "currentFuelLevelInPercent" => 62, "currentSoCInPercent" => 62, "remainingRangeInKm" => 400 },
                "secondaryEngineRange" => { "engineType" => "ELECTRIC", "currentFuelLevelInPercent" => 100, "currentSoCInPercent" => 17, "remainingRangeInKm" => 36 }
            }
        };
        var state = VehicleState.parse(vehicle, null);

        var primary = state.fuelStatus.values.get("primary") as Dictionary;
        var primaryPercent = primary.get("percent");
        if (primaryPercent != 62) {
            logger.error("primary (GASOLINE) must read currentFuelLevelInPercent, got " + _str(primaryPercent));
            return false;
        }

        var secondary = state.fuelStatus.values.get("secondary") as Dictionary;
        // Deliberately distinct from currentFuelLevelInPercent (100) above,
        // so a parser that read the wrong field for the electric engine
        // would be caught red-handed rather than accidentally passing.
        var secondaryPercent = secondary.get("percent");
        if (secondaryPercent != 17) {
            logger.error("secondary (ELECTRIC) must read currentSoCInPercent, got " + _str(secondaryPercent));
            return false;
        }
        return true;
    }

    // A future engine type not yet in openapi.json's list (DIESEL, CNG, LPG,
    // UNKNOWN, or anything newer) must still be treated as combustion:
    // i.e. read currentFuelLevelInPercent: since ELECTRIC is the only
    // engine type the fuel-level field is wrong for.
    (:test)
    function unknownEngineTypeIsTreatedAsCombustion(logger as Logger) as Boolean {
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017",
            "fuelStatus" => {
                "primaryEngineRange" => { "engineType" => "HYDROGEN_FUEL_CELL", "currentFuelLevelInPercent" => 55, "currentSoCInPercent" => 55, "remainingRangeInKm" => 300 }
            }
        };
        var state = VehicleState.parse(vehicle, null);
        var primary = state.fuelStatus.values.get("primary") as Dictionary;
        if (!(primary.get("engineType") as String).equals("HYDROGEN_FUEL_CELL")) {
            logger.error("engineType itself must still pass through verbatim");
            return false;
        }
        if (primary.get("percent") != 55) {
            logger.error("an unrecognised, non-ELECTRIC engineType must still read currentFuelLevelInPercent");
            return false;
        }
        return true;
    }

}
