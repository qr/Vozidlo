import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/StateIcons.mc (US-059/US-060): the pure state->icon
// mapping functions only: the drawing half needs a live Dc, which this
// project's existing tests never construct (see tests/ControlTilesTests.mc's
// own header comment on why the pure/drawing split exists at all).
module StateIconsTests {

    (:test)
    function lockStatusMapsAllFourDocumentedValues(logger as Logger) as Boolean {
        if (StateIcons.forLockStatus("YES") != StateIcons.LOCKED) {
            logger.error("YES must map to LOCKED");
            return false;
        }
        if (StateIcons.forLockStatus("NO") != StateIcons.UNLOCKED) {
            logger.error("NO must map to UNLOCKED");
            return false;
        }
        if (StateIcons.forLockStatus("OPENED") != StateIcons.OPEN) {
            logger.error("OPENED must map to OPEN");
            return false;
        }
        if (StateIcons.forLockStatus("TRUNK_OPENED") != StateIcons.OPEN) {
            logger.error("TRUNK_OPENED must map to OPEN");
            return false;
        }
        return true;
    }

    // US-059: "given an unknown state, then it has its own icon rather than
    // borrowing another": both a null reading and an unrecognised one must
    // land on UNKNOWN, never silently reuse one of the other four icons.
    (:test)
    function lockStatusFallsBackToUnknown(logger as Logger) as Boolean {
        if (StateIcons.forLockStatus(null) != StateIcons.UNKNOWN) {
            logger.error("no reading at all must map to UNKNOWN");
            return false;
        }
        if (StateIcons.forLockStatus("UNKNOWN") != StateIcons.UNKNOWN) {
            logger.error("the API's own UNKNOWN value must map to UNKNOWN");
            return false;
        }
        if (StateIcons.forLockStatus("PARTIALLY_LOCKED") != StateIcons.UNKNOWN) {
            logger.error("an unrecognised value must fall back to UNKNOWN, not crash or borrow another icon");
            return false;
        }
        return true;
    }

    (:test)
    function chargingStatusMapsActivelyChargingAndPluggedInSeparately(logger as Logger) as Boolean {
        if (StateIcons.forChargingStatus("CHARGING") != StateIcons.CHARGING) {
            logger.error("CHARGING must map to the CHARGING icon");
            return false;
        }
        if (StateIcons.forChargingStatus("READY_FOR_CHARGING") != StateIcons.PLUGGED_IN) {
            logger.error("READY_FOR_CHARGING must map to PLUGGED_IN, not CHARGING");
            return false;
        }
        if (StateIcons.forChargingStatus("CONSERVING") != StateIcons.PLUGGED_IN) {
            logger.error("CONSERVING must map to PLUGGED_IN");
            return false;
        }
        if (StateIcons.forChargingStatus("CHARGING_INTERRUPTED") != StateIcons.PLUGGED_IN) {
            logger.error("CHARGING_INTERRUPTED must map to PLUGGED_IN");
            return false;
        }
        return true;
    }

    // A "blank icon slot" (null) is a deliberate, distinct outcome from
    // UNKNOWN (see StateIcons.forChargingStatus()'s own comment) for a
    // state that simply doesn't warrant either the charging or plugged-in
    // icon, not "no data yet".
    (:test)
    function chargingStatusReturnsNullWhenNeitherIconApplies(logger as Logger) as Boolean {
        if (StateIcons.forChargingStatus(null) != null) {
            logger.error("no reading at all must be a blank slot, not UNKNOWN");
            return false;
        }
        if (StateIcons.forChargingStatus("CONNECT_CABLE") != null) {
            logger.error("CONNECT_CABLE (no cable) must not show the plugged-in icon");
            return false;
        }
        if (StateIcons.forChargingStatus("DISCHARGING") != null) {
            logger.error("DISCHARGING must not show either charging icon");
            return false;
        }
        return true;
    }

    (:test)
    function climateStatusMapsAllFourRunningValues(logger as Logger) as Boolean {
        if (StateIcons.forClimateStatus("HEATING") != StateIcons.CLIMATE_ACTIVE) {
            logger.error("HEATING must map to CLIMATE_ACTIVE");
            return false;
        }
        if (StateIcons.forClimateStatus("COOLING") != StateIcons.CLIMATE_ACTIVE) {
            logger.error("COOLING must map to CLIMATE_ACTIVE");
            return false;
        }
        if (StateIcons.forClimateStatus("VENTILATION") != StateIcons.CLIMATE_ACTIVE) {
            logger.error("VENTILATION must map to CLIMATE_ACTIVE");
            return false;
        }
        if (StateIcons.forClimateStatus("HEATING_AUXILIARY") != StateIcons.CLIMATE_ACTIVE) {
            logger.error("HEATING_AUXILIARY must map to CLIMATE_ACTIVE");
            return false;
        }
        return true;
    }

    (:test)
    function climateStatusReturnsNullWhenOff(logger as Logger) as Boolean {
        if (StateIcons.forClimateStatus("OFF") != null) {
            logger.error("OFF must be a blank slot, not an icon");
            return false;
        }
        if (StateIcons.forClimateStatus(null) != null) {
            logger.error("no reading at all must be a blank slot");
            return false;
        }
        return true;
    }

}
