import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure half of ui/StatusPages.mc: which pages exist
// (US-014/US-015), the lock grid order (A9) and the page strings (C2).
module StatusPagesTests {

    function _section(kind as String, values as Dictionary) as VehicleState.Section {
        return new VehicleState.Section(kind, kind.equals(VehicleState.KIND_PRESENT) ? 1000 : null, values);
    }

    function _vehicle(status as String, fuel as String, charging as String, odometer as String, ac as String) as VehicleState.Vehicle {
        return new VehicleState.Vehicle(null, null, null,
            _section(status, {}), _section(charging, {}), _section(fuel, {}),
            _section(odometer, {}), _section(ac, {}));
    }

    function _joined(items as Array<String>) as String {
        var s = "";
        for (var i = 0; i < items.size(); i += 1) {
            s += (i > 0 ? "," : "") + (items[i] as String);
        }
        return s;
    }

    function _expect(logger as Logger, what as String, got as String, want as String) as Boolean {
        if (!got.equals(want)) {
            logger.error(what + ": expected '" + want + "', got '" + got + "'");
            return false;
        }
        return true;
    }

    function _chipText(chips as Array<Chips.Chip>) as String {
        var s = "";
        for (var i = 0; i < chips.size(); i += 1) {
            var c = chips[i] as Chips.Chip;
            s += (i > 0 ? "," : "") + (c.kind == :warn ? "!" : "") + c.text + (c.icon == :check ? "+" : "");
        }
        return s;
    }

    // US-014: an UNSUPPORTED section never becomes a page; order unchanged.
    (:test)
    function visibleKeysHideUnsupported(logger as Logger) as Boolean {
        var p = VehicleState.KIND_PRESENT;
        var v = _vehicle(p, VehicleState.KIND_UNSUPPORTED, p, p, VehicleState.KIND_UNSUPPORTED);
        return _expect(logger, "keys", _joined(StatusPages.visibleKeys(v)), "status,charging,odometer");
    }

    // US-015: unavailable, switched off and never fetched keep their page.
    (:test)
    function visibleKeysKeepOtherKinds(logger as Logger) as Boolean {
        var v = _vehicle(VehicleState.KIND_UNKNOWN, VehicleState.KIND_UNAVAILABLE, VehicleState.KIND_DISABLED,
            VehicleState.KIND_PRESENT, VehicleState.KIND_UNKNOWN);
        return _expect(logger, "keys", _joined(StatusPages.visibleKeys(v)),
            "status,fuelStatus,charging,odometer,airConditioning");
    }

    // Never zero pages, and no vehicle at all still shows every page.
    (:test)
    function visibleKeysNeverEmpty(logger as Logger) as Boolean {
        var u = VehicleState.KIND_UNSUPPORTED;
        return _expect(logger, "all unsupported", _joined(StatusPages.visibleKeys(_vehicle(u, u, u, u, u))), "status")
            && _expect(logger, "no vehicle", _joined(StatusPages.visibleKeys(null)),
                "status,fuelStatus,charging,odometer,airConditioning");
    }

    // A9: an open item comes first; the rest keep the grid order.
    (:test)
    function lockItemsPutOpenFirst(logger as Logger) as Boolean {
        var values = { "doors" => "CLOSED", "windows" => "CLOSED", "bonnet" => "CLOSED", "trunk" => "OPEN",
            "lights" => "OFF", "sunroof" => "CLOSED" };
        return _expect(logger, "chips", _chipText(StatusPages.lockItems(values)),
            "!Trunk,Doors+,Windows+,Bonnet+,Lights+,Sunroof+");
    }

    // UNSUPPORTED and missing fields drop out; UNKNOWN gets no check.
    (:test)
    function lockItemsDropUnsupported(logger as Logger) as Boolean {
        var values = { "doors" => "UNKNOWN", "windows" => "UNSUPPORTED", "bonnet" => "CLOSED", "trunk" => "CLOSED",
            "lights" => "OFF", "sunroof" => "UNSUPPORTED" };
        return _expect(logger, "chips", _chipText(StatusPages.lockItems(values)), "Doors,Bonnet+,Trunk+,Lights+");
    }

    // An insecure item is never hidden: everything open still yields six
    // warn chips, lights on included.
    (:test)
    function lockItemsNeverHideInsecure(logger as Logger) as Boolean {
        var values = { "doors" => "OPEN", "windows" => "OPEN", "bonnet" => "OPEN", "trunk" => "OPEN",
            "lights" => "ON", "sunroof" => "OPEN" };
        return _expect(logger, "chips", _chipText(StatusPages.lockItems(values)),
            "!Doors,!Windows,!Bonnet,!Trunk,!Lights,!Sunroof");
    }

    // C2 strings: fuel per engine, short charging page, heating lines.
    (:test)
    function pagesCarryPocStrings(logger as Logger) as Boolean {
        var fuel = StatusPages.build("fuelStatus", _section(VehicleState.KIND_PRESENT, {
            "totalRangeInKm" => 436,
            "primary" => { "engineType" => "GASOLINE", "percent" => 62 },
            "secondary" => { "engineType" => "ELECTRIC", "percent" => 100.0f }
        }));
        var charging = StatusPages.build("charging", _section(VehicleState.KIND_PRESENT, {
            "batterySocPercent" => 100, "state" => "READY_FOR_CHARGING", "rangeMeters" => 36400
        }));
        var ac = StatusPages.build("airConditioning", _section(VehicleState.KIND_PRESENT, {
            "state" => "OFF", "windowHeatingFront" => "OFF", "windowHeatingRear" => "UNSUPPORTED"
        }));
        return _expect(logger, "fuel hero", fuel.main + " " + (fuel.unit as String), "436 km")
            && _expect(logger, "fuel lines", _joined(fuel.lines), "Petrol 62%,Electric 100%")
            && _expect(logger, "charging hero", charging.main, "100%")
            && _expect(logger, "charging lines", _joined(charging.lines), "Plugged in,36 km range")
            && _expect(logger, "ac hero", ac.main, "Off")
            && _expect(logger, "ac lines", _joined(ac.lines), "Windscreen heat off");
    }

    // A7 and US-008: no data asks for START; a missing value is a dash with
    // no unit; the lock hero turns amber when insecure.
    (:test)
    function emptyAndMissingValues(logger as Logger) as Boolean {
        var empty = StatusPages.build("odometer", _section(VehicleState.KIND_UNKNOWN, {}));
        var odo = StatusPages.build("odometer", _section(VehicleState.KIND_PRESENT, {}));
        var lock = StatusPages.build("status", _section(VehicleState.KIND_PRESENT, { "doorsLocked" => "TRUNK_OPENED" }));
        if (empty.kind != :empty || odo.unit != null || lock.color != Theme.WARNING) {
            logger.error("wrong kind, unit or lock colour");
            return false;
        }
        return _expect(logger, "empty", empty.main + "/" + (empty.sub as String), "No data yet/START to refresh")
            && _expect(logger, "odometer", odo.main, Labels.DASH)
            && _expect(logger, "lock", lock.main, "Trunk open");
    }

}
