import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Parses a decoded VehicleResponse (the "vehicle" object plus its sibling
// "errors" array from GET /vehicles/{vin}) into the projection the status
// pages (StatusModel.mc, StatusPages.mc) draw from (US-008 through US-015).
//
// This is deliberately a SEPARATE projection from model/Cache.mc, not a
// reuse of it, even though the two look similar at a glance:
//   - Cache.mc's job is to fit inside Application.Storage's 8 KB-per-key
//     limit, so it keeps a bare minimum of scalar fields and throws away
//     which VehicleError, if any, explained an absent section.
//   - This module's job is to drive a live screen, so it keeps that error
//     classification (US-014/US-015: UNSUPPORTED vs UNAVAILABLE vs DISABLED
//     is a real, user-visible distinction) and is never persisted itself:
//     StatusModel asks Cache for the compact form when there is no live
//     response to parse (no BLE connection, US-013).
//
// Every section is optional and every field inside it is optional (US-008's
// "any value missing renders as an em dash, never a zero or a stale value"
// starts here: a field this module could not find is null, full stop. It
// is the screens' job (Labels.DASH) to turn null into an em dash, never this module's job
// to invent a placeholder value).
module VehicleState {

    // A section's presence/availability, derived from whether the vehicle
    // dictionary carries the key at all and, when it does not, from
    // errors[] (US-014/US-015). Distinct string constants (not the raw
    // VehicleError "type" values) so a caller can compare with `.equals()`
    // without caring about the exact wire spelling.
    const KIND_PRESENT as String = "present";
    // Reported explicitly via a "*_UNSUPPORTED" error, OR simply absent with
    // no error at all: openapi.json documents that "*_UNSUPPORTED errors
    // are only reported for parts explicitly requested via the `include`
    // parameter; when `include` is omitted, unsupported parts are simply
    // absent without an error", so an unexplained absence gets the same
    // "hide this permanently" treatment as an explicit UNSUPPORTED.
    const KIND_UNSUPPORTED as String = "unsupported";
    const KIND_UNAVAILABLE as String = "unavailable";
    const KIND_DISABLED as String = "disabled";
    // Not one of the API's own distinctions: StatusModel uses this for a
    // section it has never fetched at all (US-013: reconstructing a Vehicle
    // from Cache.mc when there is no BLE connection, and Cache.mc does not
    // persist which VehicleError, if any, explained a section's absence).
    // Deliberately kept apart from KIND_UNSUPPORTED, which means "this
    // vehicle will never have this". "Not fetched yet" must not be shown
    // as if it were a permanent property of the car.
    const KIND_UNKNOWN as String = "unknown";

    // One section (status, charging, fuelStatus, odometer or
    // airConditioning). `age` is the section's own carCapturedTimestamp,
    // parsed to seconds-since-epoch (US-009: never one global timestamp);
    // it is null exactly when there is nothing to show at all. `values` is
    // the parsed fields for a PRESENT section, always present as an empty
    // Dictionary otherwise so callers never need a null check before
    // `.get()`.
    class Section {
        public var kind as String;
        public var age as Number?;
        public var values as Dictionary;

        function initialize(sectionKind as String, sectionAge as Number?, sectionValues as Dictionary) {
            kind = sectionKind;
            age = sectionAge;
            values = sectionValues;
        }

        function isPresent() as Boolean {
            return kind.equals(KIND_PRESENT);
        }
    }

    // The parsed projection of one GET /vehicles/{vin} response.
    class Vehicle {
        public var vin as String?;
        public var name as String?;
        // null means "treat every operation as possibly supported": either
        // errors[] carried OPERATIONS_UNAVAILABLE, or operations[] was
        // simply not part of this response. US-014: "when operations is
        // absent, show all actions and rely on per-command error handling."
        public var operations as Array<String>?;
        public var status as Section;
        public var charging as Section;
        public var fuelStatus as Section;
        public var odometer as Section;
        public var airConditioning as Section;

        function initialize(
            vehicleVin as String?, vehicleName as String?, vehicleOperations as Array<String>?,
            statusSection as Section, chargingSection as Section, fuelStatusSection as Section,
            odometerSection as Section, airConditioningSection as Section
        ) {
            vin = vehicleVin;
            name = vehicleName;
            operations = vehicleOperations;
            status = statusSection;
            charging = chargingSection;
            fuelStatus = fuelStatusSection;
            odometer = odometerSection;
            airConditioning = airConditioningSection;
        }

        // US-014: an operation not named here must still be offered when
        // `operations` itself is unknown: only an explicit list narrows it.
        function hasOperation(operationName as String) as Boolean {
            var ops = operations;
            if (ops == null) {
                return true;
            }
            for (var i = 0; i < ops.size(); i += 1) {
                if ((ops[i] as String).equals(operationName)) {
                    return true;
                }
            }
            return false;
        }
    }

    // `vehicle` is response.get("vehicle") (required by the schema: never
    // null itself); `errors` is response.get("errors"), which may be null,
    // empty, or non-empty on a perfectly normal 200 (US-015).
    function parse(vehicle as Dictionary, errors as Array?) as Vehicle {
        var now = Time.now().value();

        var rawOperations = vehicle.get("operations") as Array?;
        var operations = (rawOperations != null) ? _operationNames(rawOperations) : null;

        return new Vehicle(
            vehicle.get("vin") as String?,
            vehicle.get("name") as String?,
            operations,
            _section(vehicle, errors, now, "status", "VEHICLE_STATUS_UNSUPPORTED", "VEHICLE_STATUS_UNAVAILABLE", "VEHICLE_STATUS_DISABLED"),
            _section(vehicle, errors, now, "charging", "CHARGING_UNSUPPORTED", "CHARGING_UNAVAILABLE", "CHARGING_DISABLED"),
            _section(vehicle, errors, now, "fuelStatus", "FUEL_STATUS_UNSUPPORTED", "FUEL_STATUS_UNAVAILABLE", "FUEL_STATUS_DISABLED"),
            _section(vehicle, errors, now, "odometer", "ODOMETER_UNSUPPORTED", "ODOMETER_UNAVAILABLE", "ODOMETER_DISABLED"),
            _section(vehicle, errors, now, "airConditioning", "AIR_CONDITIONING_UNSUPPORTED", "AIR_CONDITIONING_UNAVAILABLE", "AIR_CONDITIONING_DISABLED")
        );
    }

    // Builds one Section: PRESENT with its projected values and age when
    // `key` is in `vehicle`, otherwise a kind derived from `errors` (or
    // KIND_UNSUPPORTED when nothing explains the absence at all, see the
    // KIND_UNSUPPORTED comment above).
    function _section(
        vehicle as Dictionary, errors as Array?, now as Number, key as String,
        unsupportedType as String, unavailableType as String, disabledType as String
    ) as Section {
        var raw = vehicle.get(key) as Dictionary?;
        if (raw != null) {
            return new Section(KIND_PRESENT, _age(raw, now), _values(key, raw));
        }
        return new Section(_kindForAbsence(errors, unsupportedType, unavailableType, disabledType), null, {});
    }

    function _kindForAbsence(errors as Array?, unsupportedType as String, unavailableType as String, disabledType as String) as String {
        if (errors != null) {
            for (var i = 0; i < errors.size(); i += 1) {
                var entry = errors[i] as Dictionary;
                var errorType = entry.get("type") as String?;
                if (errorType == null) {
                    continue;
                }
                if (errorType.equals(unavailableType)) {
                    return KIND_UNAVAILABLE;
                }
                if (errorType.equals(disabledType)) {
                    return KIND_DISABLED;
                }
                if (errorType.equals(unsupportedType)) {
                    return KIND_UNSUPPORTED;
                }
            }
        }
        return KIND_UNSUPPORTED;
    }

    function _values(key as String, raw as Dictionary) as Dictionary {
        if (key.equals("status")) {
            return _statusValues(raw);
        }
        if (key.equals("charging")) {
            return _chargingValues(raw);
        }
        if (key.equals("fuelStatus")) {
            return _fuelStatusValues(raw);
        }
        if (key.equals("odometer")) {
            return { "mileageKm" => raw.get("mileageInKm") };
        }
        // "airConditioning"
        return _airConditioningValues(raw);
    }

    // US-019: front and rear are reported separately and must stay that way
    //: windowHeating itself may be entirely absent (an older vehicle that
    // never sends it), which is exactly what a null windowHeatingFront/Rear
    // here means; the climate status page only draws a line when the value
    // is present AND not "UNSUPPORTED" (see StatusPages.mc's US-019
    // branch), never inferring a state from an absent "enabled" field.
    function _airConditioningValues(raw as Dictionary) as Dictionary {
        var windowHeating = raw.get("windowHeating") as Dictionary?;
        return {
            "state" => raw.get("state"),
            "windowHeatingFront" => (windowHeating != null) ? windowHeating.get("front") : null,
            "windowHeatingRear" => (windowHeating != null) ? windowHeating.get("rear") : null
        };
    }

    // US-010. Every value here is carried through verbatim, including one
    // this module has never seen before (see _statusValues below and
    // unrecognisedEnumValuesPassThrough in VehicleStateTests.mc), because
    // openapi.json documents that clients "must tolerate values they do not
    // recognize", and tolerating means passing through, not translating or
    // rejecting. Deciding what a value MEANS for display (e.g. hiding
    // `windows` when it reads "UNSUPPORTED") is StatusPages.mc's job, not this
    // parser's: this keeps the parser honest about what the API actually
    // said.
    function _statusValues(raw as Dictionary) as Dictionary {
        var overall = raw.get("overall") as Dictionary?;
        var detail = raw.get("detail") as Dictionary?;
        return {
            "doorsLocked" => (overall != null) ? overall.get("doorsLocked") : null,
            "locked" => (overall != null) ? overall.get("locked") : null,
            "reliableLockStatus" => (overall != null) ? overall.get("reliableLockStatus") : null,
            "doors" => (overall != null) ? overall.get("doors") : null,
            "windows" => (overall != null) ? overall.get("windows") : null,
            "lights" => (overall != null) ? overall.get("lights") : null,
            "bonnet" => (detail != null) ? detail.get("bonnet") : null,
            "trunk" => (detail != null) ? detail.get("trunk") : null,
            "sunroof" => (detail != null) ? detail.get("sunroof") : null
        };
    }

    function _chargingValues(raw as Dictionary) as Dictionary {
        var status = raw.get("status") as Dictionary?;
        var settings = raw.get("settings") as Dictionary?;
        var battery = (status != null) ? (status.get("battery") as Dictionary?) : null;
        return {
            "state" => (status != null) ? status.get("state") : null,
            "chargeType" => (status != null) ? status.get("chargeType") : null,
            "rateKmH" => (status != null) ? status.get("chargingRateInKilometersPerHour") : null,
            "powerKw" => (status != null) ? status.get("chargePowerInKw") : null,
            "remainingMinutes" => (status != null) ? status.get("remainingTimeToFullyChargedInMinutes") : null,
            "batterySocPercent" => (battery != null) ? battery.get("stateOfChargeInPercent") : null,
            "rangeMeters" => (battery != null) ? battery.get("remainingCruisingRangeInMeters") : null,
            "targetSocPercent" => (settings != null) ? settings.get("targetStateOfChargeInPercent") : null,
            "preferredChargeMode" => (settings != null) ? settings.get("preferredChargeMode") : null,
            "availableChargeModes" => (settings != null) ? settings.get("availableChargeModes") : null,
            "isInSavedLocation" => raw.get("isVehicleInSavedLocation")
        };
    }

    function _fuelStatusValues(raw as Dictionary) as Dictionary {
        return {
            "carType" => raw.get("carType"),
            "totalRangeInKm" => raw.get("totalRangeInKm"),
            "primary" => _engineValues(raw.get("primaryEngineRange") as Dictionary?),
            "secondary" => _engineValues(raw.get("secondaryEngineRange") as Dictionary?)
        };
    }

    // US-011 / the task's hybrid warning: the API fills BOTH
    // currentFuelLevelInPercent and currentSoCInPercent for a combustion
    // engine (with the same, meaningless-if-misread number), so which one to
    // read is decided by this engine's OWN `engineType`, never by position
    // (primary/secondary) or by vehicle-level `carType`. An ELECTRIC engine
    // reads currentSoCInPercent; everything else (GASOLINE, DIESEL, CNG,
    // LPG, UNKNOWN, or a future value not in that list) reads
    // currentFuelLevelInPercent, because that is the field the API
    // documents as meaningful for a combustion engine and "UNKNOWN" is
    // explicitly a combustion-family value, not an electric one.
    function _engineValues(raw as Dictionary?) as Dictionary? {
        if (raw == null) {
            return null;
        }
        var engineType = raw.get("engineType") as String?;
        var percent;
        if (engineType != null && engineType.equals("ELECTRIC")) {
            percent = raw.get("currentSoCInPercent");
        } else {
            percent = raw.get("currentFuelLevelInPercent");
        }
        return {
            "engineType" => engineType,
            "percent" => percent,
            "rangeKm" => raw.get("remainingRangeInKm")
        };
    }

    function _operationNames(raw as Array) as Array<String> {
        var names = [] as Array<String>;
        for (var i = 0; i < raw.size(); i += 1) {
            var operation = raw[i] as Dictionary;
            var operationName = operation.get("name") as String?;
            if (operationName != null) {
                names.add(operationName);
            }
        }
        return names;
    }

    // US-009: falls back to "now" exactly like Cache._sectionAge does, for
    // the same reason: a section with no parseable carCapturedTimestamp at
    // all must still get an age rather than crash or silently mean "always
    // fresh".
    function _age(raw as Dictionary, now as Number) as Number {
        var timestamp = raw.get("carCapturedTimestamp") as String?;
        if (timestamp != null) {
            var parsed = _parseIso8601(timestamp);
            if (parsed != null) {
                return parsed;
            }
        }
        return now;
    }

    // Duplicated from Cache.mc rather than called into it: Cache.mc is
    // task 4's file (owned by task 4/5 in this project's task split) and
    // exposes no public date parser, and Monkey C modules have no `private`
    // to make one module's internal helper unreachable from another, see
    // Settings.mc's own comment on the same limitation. Copying this one,
    // small, already-tested shape ("2021-06-01T12:00Z" / "...T12:00:00Z" /
    // "...T07:22:01.812Z") is cheaper and safer than reaching across an
    // ownership boundary into a file this task does not control.
    function _parseIso8601(value as String) as Number? {
        if (value.length() < 16) {
            return null;
        }
        var year = _substringToNumber(value, 0, 4);
        var month = _substringToNumber(value, 5, 7);
        var day = _substringToNumber(value, 8, 10);
        var hour = _substringToNumber(value, 11, 13);
        var minute = _substringToNumber(value, 14, 16);
        if (year == null || month == null || day == null || hour == null || minute == null) {
            return null;
        }

        var second = 0;
        if (value.length() >= 19) {
            var separator = value.substring(16, 17);
            if (separator != null && separator.equals(":")) {
                var secondValue = _substringToNumber(value, 17, 19);
                if (secondValue != null) {
                    second = secondValue;
                }
            }
        }

        var moment = Gregorian.moment({
            :year => year, :month => month, :day => day,
            :hour => hour, :minute => minute, :second => second
        });
        return moment.value();
    }

    function _substringToNumber(value as String, start as Number, end as Number) as Number? {
        var part = value.substring(start, end);
        if (part == null) {
            return null;
        }
        return part.toNumber();
    }

}
