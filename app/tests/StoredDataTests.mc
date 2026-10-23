import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/StoredData.mc (US-007): "Clear stored data" leaves
// nothing about the user or the car behind, which is what the privacy
// policy promises, and keeps the preferences.
module StoredDataTests {

    // Every Storage key that holds user or car data, by its owner's constant,
    // so a renamed key cannot make this test pass by writing a key nobody
    // reads.
    function _keys() as Array<String> {
        return [Cache.STORAGE_KEY, Quota.STORAGE_KEY, KeyLifetime.STORAGE_KEY, LastParked.STORAGE_KEY,
            ParkingFeature.STORAGE_KEY, TileOrder._ORDER_STORAGE_KEY, TileOrder._HIDDEN_STORAGE_KEY] as Array<String>;
    }

    (:test)
    function clearAllLeavesNoUserOrCarDataBehind(logger as Logger) as Boolean {
        var saved = {} as Dictionary<String, Properties.ValueType>;
        var props = ["ApiKey", "Vin", "Spin", "TemperatureUnit"] as Array<String>;
        for (var i = 0; i < props.size(); i += 1) {
            saved.put(props[i], Properties.getValue(props[i]));
        }

        var keys = _keys();
        for (var i = 0; i < keys.size(); i += 1) {
            Storage.setValue(keys[i], "x");
        }
        Properties.setValue("ApiKey", "key");
        Properties.setValue("Vin", "VIN");
        Properties.setValue("Spin", "1234");
        var unit = Properties.getValue("TemperatureUnit") as Number;

        StoredData.clearAll();

        var ok = true;
        for (var i = 0; i < keys.size(); i += 1) {
            if (Storage.getValue(keys[i]) != null) {
                logger.error(keys[i] + " is still stored");
                ok = false;
            }
        }
        var cleared = ["ApiKey", "Vin", "Spin"] as Array<String>;
        for (var i = 0; i < cleared.size(); i += 1) {
            if (!"".equals(Properties.getValue(cleared[i]))) {
                logger.error(cleared[i] + " is not empty");
                ok = false;
            }
        }
        if ((Properties.getValue("TemperatureUnit") as Number) != unit) {
            logger.error("TemperatureUnit is a preference and must stay");
            ok = false;
        }

        for (var i = 0; i < props.size(); i += 1) {
            Properties.setValue(props[i], saved.get(props[i]) as Properties.ValueType);
        }
        return ok;
    }

}
