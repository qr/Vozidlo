import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.PersistedContent;

// US-007 "Clear stored data": everything the app keeps about the user and
// the car, in one place, so the action and the privacy policy's "removes
// everything listed above" cannot drift apart again (up to 1.2 the action
// left the last parked position, the parking flag, the tile order and the
// saved waypoint behind). Each store keeps its own clear(); this only names
// them all.
//
// Left alone on purpose: preferences that say nothing about the user or
// the car (TemperatureUnit, TargetTemperature, CheckAfterCommand,
// ConfirmCommands), the developer's MockBaseUrl, and the monochrome test
// switch.
module StoredData {

    function clearAll() as Void {
        Properties.setValue("ApiKey", "");
        Properties.setValue("Vin", "");
        Properties.setValue("Spin", "");

        Cache.clear();
        Quota.clear();
        KeyLifetime.clear();
        LastParked.clear();
        ParkingFeature.clear();
        TileOrder.clear();
        CarNavigation.removeSaved();

        // The complications still carry the last published values; with
        // the cache gone they publish the placeholder instead.
        VehicleComplications.publish();
    }

}
