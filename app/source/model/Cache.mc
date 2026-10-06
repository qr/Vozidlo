import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Persists a compact projection of the vehicle response in Application.
// Storage (US-041), so the app can show the last known state immediately on
// launch, before it has made a single request. Storage allows only Number,
// Float, Long, Double, Char, String, Boolean, Array and Dictionary:
// containers included, see docs/best-practices, "Storage, Properties and
// Settings are three different things", so this module stores a hand-picked
// subset of the API response, never the raw decoded body.
//
// A response only ever describes the sections it actually returned: a
// partial response simply omits the rest (see VehicleResponse.errors[] in
// openapi.json), so update() only ever touches the sections present in what
// it is given; every other section, and its age, is left exactly as it was.
//
// (:glance), because ui/GlanceView.mc reads section()/sectionAge() while
// running in glance scope. Code without that annotation is not compiled
// into the glance binary at all, so calling it there crashes rather than
// merely straining the 65,536 B arena, see ui/GlanceView.mc's header.
(:glance)
module Cache {

    const STORAGE_KEY = "vehicleCache";

    function _load() as Dictionary {
        var stored = Storage.getValue(STORAGE_KEY);
        if (stored instanceof Dictionary) {
            return stored as Dictionary;
        }
        return { "vin" => null, "name" => null, "operations" => null, "sections" => {}, "ages" => {} };
    }

    function _save(state as Dictionary) as Void {
        Storage.setValue(STORAGE_KEY, state as Storage.ValueType);
    }

    // `vehicle` is the decoded "vehicle" object from a VehicleResponse (i.e.
    // response.get("vehicle")). `errors` is that response's "errors" array:
    // accepted for callers that want to log or surface it, but not itself
    // stored: a section's absence from `vehicle` is already everything
    // update() needs to know in order to leave it untouched.
    function update(vehicle as Dictionary, errors as Array?) as Void {
        var state = _load();
        var sections = state.get("sections") as Dictionary;
        var ages = state.get("ages") as Dictionary;
        var now = Time.now().value();

        var vin = vehicle.get("vin") as String?;
        if (vin != null) {
            state.put("vin", vin);
        }
        var name = vehicle.get("name") as String?;
        if (name != null) {
            state.put("name", name);
        }

        var status = vehicle.get("status") as Dictionary?;
        if (status != null) {
            sections.put("status", _projectStatus(status));
            ages.put("status", _sectionAge(status, now));
        }

        var fuelStatus = vehicle.get("fuelStatus") as Dictionary?;
        if (fuelStatus != null) {
            sections.put("fuelStatus", _projectFuelStatus(fuelStatus));
            ages.put("fuelStatus", _sectionAge(fuelStatus, now));
        }

        var odometer = vehicle.get("odometer") as Dictionary?;
        if (odometer != null) {
            sections.put("odometer", _projectOdometer(odometer));
            ages.put("odometer", _sectionAge(odometer, now));
        }

        var parkingPosition = vehicle.get("parkingPosition") as Dictionary?;
        if (parkingPosition != null) {
            sections.put("parkingPosition", _projectParkingPosition(parkingPosition));
            ages.put("parkingPosition", _sectionAge(parkingPosition, now));
        }

        var airConditioning = vehicle.get("airConditioning") as Dictionary?;
        if (airConditioning != null) {
            sections.put("airConditioning", _projectAirConditioning(airConditioning));
            ages.put("airConditioning", _sectionAge(airConditioning, now));
        }

        var charging = vehicle.get("charging") as Dictionary?;
        if (charging != null) {
            sections.put("charging", _projectCharging(charging));
            ages.put("charging", _sectionAge(charging, now));
        }

        // Operations is a capability list, not a timestamped reading: it has
        // no carCapturedTimestamp of its own, so it is stored without an age.
        var operations = vehicle.get("operations") as Array?;
        if (operations != null) {
            state.put("operations", _projectOperations(operations));
        }

        state.put("sections", sections);
        state.put("ages", ages);
        _save(state);
    }

    function vin() as String? {
        return _load().get("vin") as String?;
    }

    function name() as String? {
        return _load().get("name") as String?;
    }

    function operations() as Array? {
        return _load().get("operations") as Array?;
    }

    // The compact, projected form of one section (e.g. "charging"), or null
    // when that section has never been cached.
    function section(sectionName as String) as Dictionary? {
        var sections = _load().get("sections") as Dictionary?;
        if (sections == null) {
            return null;
        }
        return sections.get(sectionName) as Dictionary?;
    }

    // Seconds-since-epoch the section was last captured (the vehicle's own
    // carCapturedTimestamp when the response carried a parseable one,
    // otherwise the time this cache entry was written), or null when this
    // section has never been cached at all.
    function sectionAge(sectionName as String) as Number? {
        var ages = _load().get("ages") as Dictionary?;
        if (ages == null) {
            return null;
        }
        return ages.get(sectionName) as Number?;
    }

    // Test-only, and a legitimate building block for a future "clear stored
    // data" action (US-062 lists it as one of the confirm-first commands).
    function clear() as Void {
        Storage.deleteValue(STORAGE_KEY);
    }

    function _sectionAge(raw as Dictionary, now as Number) as Number {
        var timestamp = raw.get("carCapturedTimestamp") as String?;
        if (timestamp != null) {
            var parsed = _parseIso8601(timestamp);
            if (parsed != null) {
                return parsed;
            }
        }
        return now;
    }

    // Field names here are deliberately short: this is Storage, not a wire
    // format, and every byte here counts against the 8 KB per-key limit.
    // Enum-ish fields (state, doorsLocked, ...) are copied through verbatim,
    // never validated against a known set: openapi.json documents that new
    // values may appear over time and callers "must tolerate values they do
    // not recognize": that tolerance is "don't reject it", not "translate
    // it", so it belongs to whatever later displays the value, not here.

    function _projectStatus(raw as Dictionary) as Dictionary {
        var overall = raw.get("overall") as Dictionary?;
        var detail = raw.get("detail") as Dictionary?;
        return {
            "doorsLocked" => (overall != null) ? overall.get("doorsLocked") : null,
            "locked" => (overall != null) ? overall.get("locked") : null,
            "doors" => (overall != null) ? overall.get("doors") : null,
            "windows" => (overall != null) ? overall.get("windows") : null,
            "lights" => (overall != null) ? overall.get("lights") : null,
            "sunroof" => (detail != null) ? detail.get("sunroof") : null,
            "trunk" => (detail != null) ? detail.get("trunk") : null,
            "bonnet" => (detail != null) ? detail.get("bonnet") : null
        };
    }

    function _projectFuelStatus(raw as Dictionary) as Dictionary {
        return {
            "carType" => raw.get("carType"),
            "totalRangeInKm" => raw.get("totalRangeInKm"),
            "primary" => _projectEngineRange(raw.get("primaryEngineRange") as Dictionary?),
            "secondary" => _projectEngineRange(raw.get("secondaryEngineRange") as Dictionary?)
        };
    }

    function _projectEngineRange(raw as Dictionary?) as Dictionary? {
        if (raw == null) {
            return null;
        }
        return {
            "engineType" => raw.get("engineType"),
            "socPercent" => raw.get("currentSoCInPercent"),
            "fuelPercent" => raw.get("currentFuelLevelInPercent"),
            "rangeKm" => raw.get("remainingRangeInKm")
        };
    }

    function _projectOdometer(raw as Dictionary) as Dictionary {
        return { "mileageKm" => raw.get("mileageInKm") };
    }

    function _projectParkingPosition(raw as Dictionary) as Dictionary {
        var coords = raw.get("gpsCoordinates") as Dictionary?;
        return {
            "state" => raw.get("state"),
            "latitude" => (coords != null) ? coords.get("latitude") : null,
            "longitude" => (coords != null) ? coords.get("longitude") : null,
            "address" => raw.get("formattedAddress")
        };
    }

    function _projectAirConditioning(raw as Dictionary) as Dictionary {
        var target = raw.get("targetTemperature") as Dictionary?;
        // US-019: kept alongside the rest of this section (not a separate
        // cache entry) since it shares airConditioning's own
        // carCapturedTimestamp: there is no windowHeating-specific age to
        // track on its own.
        var windowHeating = raw.get("windowHeating") as Dictionary?;
        return {
            "state" => raw.get("state"),
            "targetValue" => (target != null) ? target.get("value") : null,
            "targetUnit" => (target != null) ? target.get("unit") : null,
            "withoutExternalPower" => raw.get("airConditioningWithoutExternalPower"),
            "atUnlock" => raw.get("airConditioningAtUnlock"),
            "windowHeatingFront" => (windowHeating != null) ? windowHeating.get("front") : null,
            "windowHeatingRear" => (windowHeating != null) ? windowHeating.get("rear") : null
        };
    }

    function _projectCharging(raw as Dictionary) as Dictionary {
        var status = raw.get("status") as Dictionary?;
        var settings = raw.get("settings") as Dictionary?;
        var battery = (status != null) ? (status.get("battery") as Dictionary?) : null;
        return {
            "isInSavedLocation" => raw.get("isVehicleInSavedLocation"),
            "state" => (status != null) ? status.get("state") : null,
            "chargeType" => (status != null) ? status.get("chargeType") : null,
            "rateKmH" => (status != null) ? status.get("chargingRateInKilometersPerHour") : null,
            "powerKw" => (status != null) ? status.get("chargePowerInKw") : null,
            "remainingMinutes" => (status != null) ? status.get("remainingTimeToFullyChargedInMinutes") : null,
            "batterySocPercent" => (battery != null) ? battery.get("stateOfChargeInPercent") : null,
            "rangeMeters" => (battery != null) ? battery.get("remainingCruisingRangeInMeters") : null,
            "targetSocPercent" => (settings != null) ? settings.get("targetStateOfChargeInPercent") : null,
            "preferredChargeMode" => (settings != null) ? settings.get("preferredChargeMode") : null,
            "availableChargeModes" => (settings != null) ? settings.get("availableChargeModes") : null
        };
    }

    function _projectOperations(raw as Array) as Array<String> {
        var names = [] as Array<String>;
        for (var i = 0; i < raw.size(); i += 1) {
            var op = raw[i] as Dictionary;
            var opName = op.get("name") as String?;
            if (opName != null) {
                names.add(opName);
            }
        }
        return names;
    }

    // A minimal ISO 8601 UTC parser for exactly the shape the API sends
    // ("2021-06-01T12:00Z", "...T12:00:00Z", "...T07:22:01.812Z"). Monkey C
    // has no date-time parser of its own. Fixed field positions rather than a
    // general splitter, since every numeric field the API sends is always
    // zero-padded to a known width.
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

        // Gregorian.moment() treats every field as UTC, matching the "Z"
        // suffix every carCapturedTimestamp carries, see
        // Toybox.Time.Gregorian.moment()'s own documentation.
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
