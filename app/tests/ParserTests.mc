import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/model/Cache.mc's projection of a decoded
// VehicleResponse into the compact form Application.Storage holds (US-041,
// US-053). Every test starts by clearing the cache so the tests do not leak
// state into each other despite sharing one Storage key for the whole run.
module ParserTests {

    // ----------------------------------------------------------- fixtures

    function _fullVehicle() as Dictionary {
        return {
            "vin" => "TMBMOCKVIN0000017",
            "name" => "My Enyaq",
            "status" => {
                "overall" => { "doorsLocked" => "YES", "locked" => "YES", "doors" => "CLOSED", "windows" => "CLOSED", "lights" => "OFF" },
                "detail" => { "sunroof" => "CLOSED", "trunk" => "CLOSED", "bonnet" => "CLOSED" },
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "fuelStatus" => {
                "carType" => "GASOLINE",
                "totalRangeInKm" => 436,
                "primaryEngineRange" => { "engineType" => "GASOLINE", "currentSoCInPercent" => null, "currentFuelLevelInPercent" => 62, "remainingRangeInKm" => 400 },
                "secondaryEngineRange" => { "engineType" => "ELECTRIC", "currentSoCInPercent" => 100, "currentFuelLevelInPercent" => null, "remainingRangeInKm" => 36 },
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "odometer" => { "mileageInKm" => 12753, "carCapturedTimestamp" => "2021-06-01T12:00:00Z" },
            "parkingPosition" => {
                "state" => "PARKED",
                "gpsCoordinates" => { "latitude" => 52.100000, "longitude" => 5.100000 },
                "formattedAddress" => "Prazska 4A, 10200 Prague, Czech Republic"
            },
            "airConditioning" => {
                "state" => "HEATING",
                "targetTemperature" => { "value" => 22.5, "unit" => "CELSIUS" },
                "airConditioningWithoutExternalPower" => true,
                "airConditioningAtUnlock" => false,
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "charging" => {
                "isVehicleInSavedLocation" => true,
                "status" => {
                    "state" => "CHARGING",
                    "chargeType" => "AC",
                    "chargingRateInKilometersPerHour" => 20.0,
                    "chargePowerInKw" => 11.0,
                    "remainingTimeToFullyChargedInMinutes" => 45,
                    "battery" => { "stateOfChargeInPercent" => 71, "remainingCruisingRangeInMeters" => 249000 }
                },
                "settings" => {
                    "targetStateOfChargeInPercent" => 80,
                    "preferredChargeMode" => "MANUAL",
                    "availableChargeModes" => []
                },
                "carCapturedTimestamp" => "2021-06-01T12:00:00Z"
            },
            "operations" => [
                { "name" => "startCharging" },
                { "name" => "stopCharging" },
                { "name" => "startAirConditioning" },
                { "name" => "stopAirConditioning" }
            ]
        };
    }

    // -------------------------------------------------------------- tests

    (:test)
    function fullResponseIsProjectedCompletely(logger as Logger) as Boolean {
        Cache.clear();
        Cache.update(_fullVehicle(), null);

        if (!(Cache.vin() as String).equals("TMBMOCKVIN0000017")) {
            logger.error("vin not stored");
            return false;
        }
        if (!(Cache.name() as String).equals("My Enyaq")) {
            logger.error("name not stored");
            return false;
        }

        var charging = Cache.section("charging");
        if (charging == null) {
            logger.error("charging section missing");
            return false;
        }
        if (!(charging.get("state") as String).equals("CHARGING")) {
            logger.error("charging.state not projected");
            return false;
        }
        if (!(charging.get("batterySocPercent") == 71)) {
            logger.error("charging.batterySocPercent not projected");
            return false;
        }

        var parking = Cache.section("parkingPosition");
        if (parking == null || !(parking.get("state") as String).equals("PARKED")) {
            logger.error("parkingPosition not projected");
            return false;
        }
        var latitude = parking.get("latitude") as Float?;
        if (latitude == null || (latitude - 52.100000).abs() > 0.0001) {
            logger.error("parkingPosition.latitude not projected");
            return false;
        }

        var operations = Cache.operations();
        if (operations == null || operations.size() != 4) {
            logger.error("operations not projected");
            return false;
        }
        if (!(operations[0] as String).equals("startCharging")) {
            logger.error("operations order/content wrong");
            return false;
        }

        // "2021-06-01T12:00:00Z" is a fixed, known instant. The parser must
        // return exactly its epoch value, not merely "some non-null number".
        var age = Cache.sectionAge("charging");
        if (age == null || age != 1622548800) {
            logger.error("charging age wrong, got " + (age != null ? age.toString() : "null"));
            return false;
        }
        return true;
    }

    // US-041 / US-053: a partial response (mock's "partial-data" scenario)
    // updates only the sections present and leaves the rest, and their
    // ages: exactly as they were.
    (:test)
    function partialResponseLeavesMissingSectionsUntouched(logger as Logger) as Boolean {
        Cache.clear();
        Cache.update(_fullVehicle(), null);
        var previousChargingAge = Cache.sectionAge("charging");
        var previousParking = Cache.section("parkingPosition");

        var partial = {
            "vin" => "TMBMOCKVIN0000017",
            "status" => {
                "overall" => { "doorsLocked" => "NO", "locked" => "NO", "doors" => "OPEN", "windows" => "CLOSED", "lights" => "OFF" },
                "detail" => { "sunroof" => "CLOSED", "trunk" => "CLOSED", "bonnet" => "CLOSED" },
                "carCapturedTimestamp" => "2021-06-01T13:00:00Z"
            }
            // charging and parkingPosition are absent, exactly as the mock's
            // partial-data scenario omits them and reports errors[] instead.
        };
        var errors = [
            { "type" => "CHARGING_UNAVAILABLE", "description" => "Charging status could not be retrieved from the vehicle." },
            { "type" => "PARKING_POSITION_DISABLED", "description" => "Parking position is supported, but currently disabled." }
        ];

        Cache.update(partial, errors);

        var status = Cache.section("status");
        if (status == null || !(status.get("doorsLocked") as String).equals("NO")) {
            logger.error("the section present in the partial response was not updated");
            return false;
        }

        var chargingAfter = Cache.section("charging");
        if (chargingAfter == null || !(chargingAfter.get("state") as String).equals("CHARGING")) {
            logger.error("charging section was cleared instead of left untouched");
            return false;
        }
        var chargingAgeAfter = Cache.sectionAge("charging");
        if (chargingAgeAfter != previousChargingAge) {
            logger.error("charging age changed even though charging was absent from the partial response");
            return false;
        }

        var parkingAfter = Cache.section("parkingPosition");
        if (parkingAfter == null || previousParking == null || !(parkingAfter.get("state") as String).equals(previousParking.get("state") as String)) {
            logger.error("parkingPosition section was not left untouched");
            return false;
        }
        return true;
    }

    // Absent optional fields: a vehicle IN_MOTION carries no gpsCoordinates
    // and no formattedAddress (US-050's "in-motion" scenario): the projector
    // must not crash and must simply carry nulls through.
    (:test)
    function absentOptionalFieldsAreTolerated(logger as Logger) as Boolean {
        Cache.clear();
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017",
            "parkingPosition" => { "state" => "IN_MOTION" }
        };
        Cache.update(vehicle, null);

        var parking = Cache.section("parkingPosition");
        if (parking == null) {
            logger.error("parkingPosition section missing");
            return false;
        }
        if (!(parking.get("state") as String).equals("IN_MOTION")) {
            logger.error("parkingPosition.state wrong");
            return false;
        }
        if (parking.get("latitude") != null || parking.get("longitude") != null || parking.get("address") != null) {
            logger.error("absent coordinates/address must project to null, not a crash or a fabricated value");
            return false;
        }

        // No carCapturedTimestamp at all: age falls back to "now" rather than
        // being left null or crashing the parser.
        if (Cache.sectionAge("parkingPosition") == null) {
            logger.error("a section with no carCapturedTimestamp must still get an age");
            return false;
        }
        return true;
    }

    // Unrecognised enum values: openapi.json documents that new values may
    // appear over time and clients "must tolerate values they do not
    // recognize": the projector must pass an unknown value through as-is,
    // not reject or crash on it.
    (:test)
    function unrecognisedEnumValuesPassThrough(logger as Logger) as Boolean {
        Cache.clear();
        var vehicle = {
            "vin" => "TMBMOCKVIN0000017",
            "airConditioning" => { "state" => "SOME_FUTURE_STATE_WE_HAVE_NEVER_SEEN" },
            "charging" => {
                "isVehicleInSavedLocation" => false,
                "status" => { "state" => "ANOTHER_FUTURE_STATE" }
            }
        };
        Cache.update(vehicle, null);

        var ac = Cache.section("airConditioning");
        if (ac == null || !(ac.get("state") as String).equals("SOME_FUTURE_STATE_WE_HAVE_NEVER_SEEN")) {
            logger.error("unrecognised airConditioning.state was not passed through unchanged");
            return false;
        }
        var charging = Cache.section("charging");
        if (charging == null || !(charging.get("state") as String).equals("ANOTHER_FUTURE_STATE")) {
            logger.error("unrecognised charging.state was not passed through unchanged");
            return false;
        }
        return true;
    }

}
