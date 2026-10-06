import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;

// Reads and validates Application.Properties (the phone-editable Settings) into a
// Settings.Config. Kept isolated here so VozidloApp and the future HTTP layer (task 4)
// never touch Properties directly, and so the VIN is validated before any request is
// ever built (US-001).
//
// (:glance), because VozidloApp.onStart() calls load(), and onStart() runs in
// glance scope as well as app scope. Code without that annotation is not
// compiled into the glance binary, so the call crashed every glance launch
// until this was added, see VozidloApp.mc's header for the full account.
(:glance)
module Settings {

    const VIN_LENGTH = 17;

    // Builds a Config from the current Properties. Called from VozidloApp.onStart() and
    // again from onSettingsChanged(), so a phone-side edit takes effect without a
    // restart.
    function load() as Config {
        var apiKey = Properties.getValue("ApiKey") as String?;
        var vin = Properties.getValue("Vin") as String?;
        var unit = Properties.getValue("TemperatureUnit") as Number?;
        var spin = Properties.getValue("Spin") as String?;
        var targetTemperature = Properties.getValue("TargetTemperature") as Number?;

        return new Config(
            apiKey != null ? apiKey : "",
            vin != null ? vin : "",
            resolveTemperatureUnit(unit),
            spin != null ? spin : "",
            targetTemperature
        );
    }

    // US-018: 0 is the "never set" sentinel (see properties.xml). 0 degrees,
    // in either unit, is not a plausible cabin target, so it is safe to
    // reserve without colliding with a real choice.
    function isTargetTemperatureSet(value as Number?) as Boolean {
        return value != null && value != 0;
    }

    // A VIN that is not exactly 17 characters must be reported before any request is
    // made (US-001). A free function so it is unit-testable without touching
    // Properties, see tests/SettingsTests.mc.
    function isVinValid(vin as String) as Boolean {
        return vin.length() == VIN_LENGTH;
    }

    // TemperatureUnit defaults to the device's system unit when the phone setting has
    // never been touched (US-005), which can only be resolved at runtime: hence this
    // lives here rather than as a static default in properties.xml. -1 is the "never
    // set" sentinel (see resources/settings/properties.xml); 0/1 mirror
    // System.UNIT_METRIC/UNIT_STATUTE.
    //
    // Modules don't support the `private` modifier (only classes do), so this is
    // public but undocumented outside the module: callers should use load().
    function resolveTemperatureUnit(unit as Number?) as String {
        if (unit != null && unit >= 0) {
            return unit == System.UNIT_STATUTE ? "F" : "C";
        }
        var deviceSettings = System.getDeviceSettings();
        return deviceSettings.temperatureUnits == System.UNIT_STATUTE ? "F" : "C";
    }

    // Parsed, validated view of the four Settings. Everything downstream (task 4's
    // HTTP layer, task 6/7 views) reads this instead of touching Properties again.
    class Config {

        public var apiKey as String;
        public var vin as String;
        public var vinValid as Boolean;
        public var temperatureUnit as String;
        public var spin as String;
        public var hasSpin as Boolean;
        // US-018: null means "no on-device/phone override yet". Task 7's
        // climate command then falls back to the value the car itself last
        // reported (see Cache's "airConditioning" section), never to a
        // number this module invented.
        public var targetTemperature as Number?;

        function initialize(key as String, vinValue as String, unit as String, spinValue as String, targetTemperatureValue as Number?) {
            apiKey = key;
            vin = vinValue;
            vinValid = Settings.isVinValid(vinValue);
            temperatureUnit = unit;
            spin = spinValue;
            // US-006: auxiliary heating is hidden from the menu entirely unless an
            // S-PIN is set: hasSpin is what tasks 6/7 will branch on.
            hasSpin = spinValue.length() > 0;
            targetTemperature = Settings.isTargetTemperatureSet(targetTemperatureValue) ? targetTemperatureValue : null;
        }

    }

}
