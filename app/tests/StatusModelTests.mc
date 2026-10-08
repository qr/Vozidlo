import Toybox.Lang;
import Toybox.Test;

// Unit tests for model/StatusModel.mc: the cache projection's fuel special
// case (US-011). The refresh toast wording is Refusal's (RefusalTests).
module StatusModelTests {

    // The API fills both percent fields for a combustion engine, so the
    // engine's own type decides which one is read back from the cache.
    (:test)
    function cachedEnginePicksPercentByType(logger as Logger) as Boolean {
        var model = new StatusModel();
        var electric = model.cachedEngine({ "engineType" => "ELECTRIC", "socPercent" => 80, "fuelPercent" => 5 }) as Dictionary;
        var petrol = model.cachedEngine({ "engineType" => "GASOLINE", "socPercent" => 5, "fuelPercent" => 62 }) as Dictionary;
        if ((electric.get("percent") as Number) != 80 || (petrol.get("percent") as Number) != 62 || model.cachedEngine(null) != null) {
            logger.error("percent read from the wrong field");
            return false;
        }
        return true;
    }

    // US-013: cached sections come back present with their age; a section
    // the cache never saw is "no data yet", not "unsupported".
    (:test)
    function fromCacheProjectsSections(logger as Logger) as Boolean {
        Cache.clear();
        Cache.update({
            "fuelStatus" => {
                "carCapturedTimestamp" => "2026-10-07T10:00:00Z",
                "totalRangeInKm" => 436,
                "primaryEngineRange" => { "engineType" => "GASOLINE", "currentFuelLevelInPercent" => 62, "currentSoCInPercent" => 62 },
                "secondaryEngineRange" => { "engineType" => "ELECTRIC", "currentSoCInPercent" => 100, "currentFuelLevelInPercent" => 0 }
            }
        }, null);
        var vehicle = (new StatusModel()).fromCache();
        Cache.clear();
        var fuel = vehicle.fuelStatus;
        if (!fuel.isPresent() || fuel.age == null) {
            logger.error("cached fuelStatus should be present with an age");
            return false;
        }
        var secondary = fuel.values.get("secondary") as Dictionary;
        if ((secondary.get("percent") as Number) != 100) {
            logger.error("electric engine should read its SoC");
            return false;
        }
        if (!vehicle.odometer.kind.equals(VehicleState.KIND_UNKNOWN)) {
            logger.error("an uncached section should be KIND_UNKNOWN");
            return false;
        }
        return true;
    }

    // The Status refresh is what keeps home's command list right: with
    // `include`, the API only returns operations when asked.
    (:test)
    function theStatusRefreshAsksForOperations(logger as Logger) as Boolean {
        var parts = [] as Array<String>;
        var rest = StatusFetch.INCLUDE;
        var comma = rest.find(",");
        while (comma != null) {
            parts.add(rest.substring(0, comma) as String);
            rest = rest.substring(comma + 1, rest.length()) as String;
            comma = rest.find(",");
        }
        parts.add(rest);
        if (parts.indexOf("operations") < 0) {
            logger.error("INCLUDE must name operations, got " + StatusFetch.INCLUDE);
            return false;
        }
        return true;
    }

}
