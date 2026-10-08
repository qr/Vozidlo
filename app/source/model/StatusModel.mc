import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Time;
import Toybox.PersistedContent;

// Data behind the status pages (US-008 through US-015), lifted out of the
// old StatusView so the pages only draw (docs/design/ui-improvements.md B5):
// one request for all pages, the cache projection for when there is nothing
// live, the quota bookkeeping and the error text.
//
// Every value comes from a VehicleState.Vehicle built either fresh from a
// live response (_onVehicleResponse) or, with nothing live yet, projected
// out of Cache.mc (US-013: cached values with their own age, even with no
// BLE connection at all). Both converge on the same Section shape, so the
// pages never need to know which one they draw.
// What the Status refresh asks for, in a module so the tests can read it.
module StatusFetch {

    // Only the sections the status pages draw: same quota cost as the
    // unfiltered read, less to parse and hold (US-008's note). Plus
    // operations: with `include` the API leaves it out unless asked
    // (measured 2026-10-08), and without it Cache.operations() stays null,
    // so home offered every command, ventilation included, on a car that
    // answers 422 to it.
    const INCLUDE = "status,charging,fuelStatus,odometer,airConditioning,operations";

}

class StatusModel {


    private var _vehicle as VehicleState.Vehicle? = null;
    private var _fetching as Boolean = false;
    // Set on any non-200 failure so the page can say something without
    // ever touching _vehicle: a failed refresh must never blank or
    // stale-overwrite what is already on screen (US-013/US-015).
    private var _lastError as String? = null;
    // Bumped whenever _vehicle is replaced, so the pager knows to recompute
    // its pages without the model holding a reference back to it.
    private var _version as Number = 0;

    function initialize() {
    }

    // Cache.mc is Storage-backed and effectively instant, which is what makes
    // the pages show something immediately, even with no BLE connection
    // (US-013). Guarded so a live refresh that already set _vehicle is never
    // clobbered by a later call (old StatusView.onShow).
    function load() as Void {
        if (_vehicle == null) {
            _vehicle = fromCache();
            _version += 1;
        }
    }

    function vehicle() as VehicleState.Vehicle? {
        return _vehicle;
    }

    function version() as Number {
        return _version;
    }

    function isFetching() as Boolean {
        return _fetching;
    }

    function lastError() as String? {
        return _lastError;
    }

    // ------------------------------------------------------------- refresh

    // Returns why nothing was sent (:busy, :offline, :quota, :unconfigured)
    // or :started, so the caller can toast it (Refusal.text). The checks and
    // their order are the old StatusView.refresh(), shared with Charging
    // detail and Find my car through Refusal: US-012/US-013 want the action
    // disabled rather than failing when pressed.
    function refresh() as Symbol {
        var verdict = Refusal.current(_fetching);
        if (verdict != :ok) {
            return verdict;
        }
        var settings = getApp().getSettings();

        _fetching = true;
        _lastError = null;
        WatchUi.requestUpdate();
        ApiClient.getVehicle(settings.vin, StatusFetch.INCLUDE, settings.apiKey, method(:_onVehicleResponse));
        return :started;
    }

    function _onVehicleResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _fetching = false;

        if (responseCode == 200) {
            var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
            if (body != null) {
                var vehicle = body.get("vehicle") as Dictionary?;
                if (vehicle != null) {
                    var errors = body.get("errors") as Array?;
                    // Persist first, project second: both from the same raw
                    // response, so a crash in one can never leave the other
                    // out of sync with what the API actually said.
                    Cache.update(vehicle, errors);
                    _vehicle = VehicleState.parse(vehicle, errors);
                    _version += 1;
                    _lastError = null;
                }
            }
            // A 200 proves this request was not being held back: clears a
            // stale Retry-After gate even with nothing fresh to report (see
            // Quota.recordHeaders()). Connect IQ cannot read response headers
            // (see ApiClient.mc), so there is no RateLimit-* to pass; this is
            // the app's own estimate, worded that way in quotaLine().
            Quota.recordHeaders(null, null, null);
            WatchUi.requestUpdate();
            return;
        }

        var errorBody = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (errorBody != null) ? (errorBody.get("type") as String?) : null;
            // Retry-After is likewise unreadable on this platform, so this
            // can only record "blocked", never "blocked until X" (Quota.mc).
            Quota.recordRateLimited(problemType, null);
        }
        // Full text: the page fits it to the circle by pixels (A5), which
        // replaces the old 42-character cut.
        _lastError = ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text;
        WatchUi.requestUpdate();
    }

    // ------------------------------------------------------------- words

    // The one transient line under the age, or null when there is nothing to
    // say (the normal case; no default "press to refresh" hint, B4). Order
    // from the old top bar: phone first because it explains why every
    // request is disabled (US-013/US-045), then a running request, the last
    // failure and the quota (US-012/US-040).
    function statusLine() as [String, Symbol]? {
        if (!(System.getDeviceSettings().phoneConnected)) {
            return [Commands.NO_PHONE, :error];
        }
        if (_fetching) {
            return ["Refreshing" + Labels.ELLIPSIS, :age];
        }
        var error = _lastError;
        if (error != null) {
            return [error, :error];
        }
        if (!Quota.canSpend()) {
            return [Refusal.quotaSpentText(Quota.secondsUntilReset()), :warn];
        }
        var remaining = Quota.remaining();
        if (remaining != null && Quota.isLow()) {
            return ["Low: ~" + remaining.toString() + " left (est.)", :warn];
        }
        return null;
    }

    // ---------------------------------------------------------- cache path

    // US-013: the same Vehicle shape straight out of Cache.mc's compact
    // projection. Every section Cache has never seen becomes KIND_UNKNOWN:
    // "no data yet", not "this car doesn't have this".
    function fromCache() as VehicleState.Vehicle {
        return new VehicleState.Vehicle(
            Cache.vin(), Cache.name(), Cache.operations() as Array<String>?,
            _cachedSection("status"),
            _cachedSection("charging"),
            _cachedFuelSection(),
            _cachedSection("odometer"),
            _cachedSection("airConditioning")
        );
    }

    function _cachedSection(key as String) as VehicleState.Section {
        var values = Cache.section(key);
        if (values == null) {
            return new VehicleState.Section(VehicleState.KIND_UNKNOWN, null, {});
        }
        return new VehicleState.Section(VehicleState.KIND_PRESENT, Cache.sectionAge(key), values);
    }

    // fuelStatus needs its own path because Cache._projectEngineRange keeps
    // BOTH currentSoCInPercent ("socPercent") and currentFuelLevelInPercent
    // ("fuelPercent"): VehicleState's "percent" resolution (the engine type
    // decides which one means something, VehicleState._engineValues) has to
    // be re-applied to Cache's already-split fields here.
    function _cachedFuelSection() as VehicleState.Section {
        var raw = Cache.section("fuelStatus");
        if (raw == null) {
            return new VehicleState.Section(VehicleState.KIND_UNKNOWN, null, {});
        }
        var values = {
            "carType" => raw.get("carType"),
            "totalRangeInKm" => raw.get("totalRangeInKm"),
            "primary" => cachedEngine(raw.get("primary") as Dictionary?),
            "secondary" => cachedEngine(raw.get("secondary") as Dictionary?)
        };
        return new VehicleState.Section(VehicleState.KIND_PRESENT, Cache.sectionAge("fuelStatus"), values);
    }

    function cachedEngine(raw as Dictionary?) as Dictionary? {
        if (raw == null) {
            return null;
        }
        var engineType = raw.get("engineType") as String?;
        var percent;
        if (engineType != null && engineType.equals("ELECTRIC")) {
            percent = raw.get("socPercent");
        } else {
            percent = raw.get("fuelPercent");
        }
        return { "engineType" => engineType, "percent" => percent, "rangeKm" => raw.get("rangeKm") };
    }

}
