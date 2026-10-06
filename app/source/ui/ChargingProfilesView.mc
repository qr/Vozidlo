import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

// One flattened, display-ready profile. A plain top-level class (Monkey C
// only allows a class to nest inside a MODULE, not inside another class:
// see model/VehicleState.mc's Section/Vehicle for the pattern this follows)
// rather than a raw Dictionary, so ChargingProfilesView.onUpdate() never
// re-parses anything (docs/best-practices: "pre-compute, then draw").
class ChargingProfileEntry {
    public var name as String;
    public var targetSoc as Number?;
    public var maxCurrent as String?;
    public var isCurrent as Boolean;
    public var nextChargingTime as String?;
    public var timerLines as Array<String>;

    function initialize(profileName as String, target as Number?, current as String?,
                         currentFlag as Boolean, nextTime as String?, timers as Array<String>) {
        name = profileName;
        targetSoc = target;
        maxCurrent = current;
        isCurrent = currentFlag;
        nextChargingTime = nextTime;
        timerLines = timers;
    }
}

// US-026 (Could): read-only charging profiles and timers. Fetched with a
// targeted `?include=chargingProfiles` the FIRST time this screen is shown
// and never bundled with anything else: docs/requirements.md US-026 is
// explicit that profiles-with-timers make the response considerably larger,
// so this is the one screen in the app that pays that cost, and only once
// per visit (onShow() guards on _hasFetched, matching the "fetch only when
// that screen opens" instruction literally).
//
// Whether this vehicle supports profiles at all can only be known by
// fetching them (there is no cheaper capability signal for this specific
// section: unlike charge mode, which has availableChargeModes to check
// before ever opening anything), so "absent entirely when unsupported"
// is realised here as: the menu item that opens this screen is always
// offered (ChargingDetailView.openMenu()), and THIS screen is what actually
// discovers and reports the absence, exactly the way every other
// "*_UNSUPPORTED" section already works elsewhere in this app (see
// VehicleState.KIND_UNSUPPORTED).
class ChargingProfilesView extends WatchUi.View {

    private var _hasFetched as Boolean = false;
    private var _fetching as Boolean = false;
    private var _supported as Boolean = false;
    private var _lastError as String? = null;

    private var _profiles as Array<ChargingProfileEntry> = [] as Array<ChargingProfileEntry>;
    private var _pageIndex as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        if (!_hasFetched) {
            _fetch();
        }
    }

    function _fetch() as Void {
        if (_fetching) {
            return;
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            _lastError = "Phone not connected";
            WatchUi.requestUpdate();
            return;
        }
        if (!Quota.canSpend()) {
            _lastError = "Quota spent for this hour";
            WatchUi.requestUpdate();
            return;
        }
        var settings = getApp().getSettings();
        if (!settings.vinValid || settings.apiKey.length() == 0) {
            return;
        }

        _fetching = true;
        _lastError = null;
        WatchUi.requestUpdate();
        // Targeted and ALONE, see the class comment above; never bundled
        // with "charging" or "operations" even though this screen is reached
        // from a screen that already fetched those, because a fresh request
        // is exactly what re-opening this screen after it was left open on
        // an earlier vehicle response would otherwise skip.
        ApiClient.getVehicle(settings.vin, "chargingProfiles", settings.apiKey, method(:_onVehicleResponse));
    }

    function _onVehicleResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _fetching = false;
        _hasFetched = true;

        if (responseCode == 200) {
            var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
            var vehicle = (body != null) ? (body.get("vehicle") as Dictionary?) : null;
            if (vehicle != null) {
                _applyProfiles(vehicle.get("chargingProfiles") as Dictionary?);
                _lastError = null;
            }
            Quota.recordHeaders(null, null, null);
            WatchUi.requestUpdate();
            return;
        }

        var errorBody = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (errorBody != null) ? (errorBody.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        _lastError = _shorten(ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text);
        WatchUi.requestUpdate();
    }

    // `raw` is vehicle.get("chargingProfiles"): null when this vehicle
    // genuinely does not support profiles (US-026: "absent entirely when
    // unsupported"; the mock's own `default` scenario is exactly this case,
    // see mock/README.md).
    function _applyProfiles(raw as Dictionary?) as Void {
        if (raw == null) {
            _supported = false;
            _profiles = [] as Array<ChargingProfileEntry>;
            return;
        }
        _supported = true;

        var currentPosition = raw.get("currentVehiclePositionProfile") as Dictionary?;
        var currentId = (currentPosition != null) ? currentPosition.get("id") : null;
        var nextChargingTime = (currentPosition != null) ? (currentPosition.get("nextChargingTime") as String?) : null;

        var rawProfiles = raw.get("profiles") as Array?;
        var built = [] as Array<ChargingProfileEntry>;
        if (rawProfiles != null) {
            for (var i = 0; i < rawProfiles.size(); i += 1) {
                var profile = rawProfiles[i] as Dictionary;
                built.add(_buildProfile(profile, currentId, nextChargingTime));
            }
        }
        _profiles = built;
        if (_pageIndex >= _profiles.size()) {
            _pageIndex = 0;
        }
    }

    function _buildProfile(profile as Dictionary, currentId as Object?, currentNextChargingTime as String?) as ChargingProfileEntry {
        var name = profile.get("name") as String?;
        var settings = profile.get("settings") as Dictionary?;
        var targetSoc = (settings != null) ? (settings.get("targetStateOfChargeInPercent") as Number?) : null;
        var maxCurrent = (settings != null) ? (settings.get("maxChargingCurrent") as String?) : null;

        var isCurrent = ChargingLogic.isCurrentProfile(profile.get("id"), currentId);

        var timers = profile.get("timers") as Array?;
        var timerLines = [] as Array<String>;
        if (timers != null) {
            for (var i = 0; i < timers.size(); i += 1) {
                var timer = timers[i] as Dictionary;
                var enabled = timer.get("enabled") as Boolean?;
                if (enabled != true) {
                    continue; // US-026: "enabled timers", never the disabled ones
                }
                var time = timer.get("time") as String?;
                var recurrence = ChargingLogic.timerRecurrenceLabel(
                    timer.get("type") as String?, timer.get("recurringOn") as Array<String>?, timer.get("oneOffDay") as String?
                );
                timerLines.add((time != null ? time : "—") + " " + recurrence);
            }
        }

        return new ChargingProfileEntry(
            (name != null) ? name : "—", targetSoc, maxCurrent, isCurrent,
            isCurrent ? currentNextChargingTime : null, timerLines
        );
    }

    // ------------------------------------------------------------ paging

    function nextPage() as Void {
        if (_profiles.size() == 0) {
            return;
        }
        _pageIndex = (_pageIndex + 1) % _profiles.size();
        WatchUi.requestUpdate();
    }

    function previousPage() as Void {
        if (_profiles.size() == 0) {
            return;
        }
        _pageIndex = (_pageIndex - 1 + _profiles.size()) % _profiles.size();
        WatchUi.requestUpdate();
    }

    // -------------------------------------------------------- rendering

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var centerX = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 12, Graphics.FONT_XTINY, "CHARGING PROFILES", Graphics.TEXT_JUSTIFY_CENTER);

        if (_fetching) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_lastError != null) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_XTINY, _lastError as String, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (!_hasFetched) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL, "SELECT to load", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (!_supported) {
            // US-026: "the section is absent". This vehicle simply does
            // not have any (the mock's default scenario, and every real
            // vehicle measured so far, see mock/README.md).
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL, "Not supported\nby this car", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_profiles.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL, "No profiles saved", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        _drawProfile(dc, centerX, _profiles[_pageIndex] as ChargingProfileEntry);

        TextBlock.drawFittedLine(dc,
            (_pageIndex + 1).toString() + "/" + _profiles.size().toString() + " - UP/DOWN",
            Graphics.FONT_XTINY, Graphics.COLOR_DK_GRAY, dc.getHeight() - 20);
    }

    function _drawProfile(dc as Dc, centerX as Number, profile as ChargingProfileEntry) as Void {
        dc.setColor(profile.isCurrent ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var title = profile.isCurrent ? (profile.name + " (here)") : profile.name;
        dc.drawText(centerX, 50, Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER);

        var lineY = 80;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY,
            "Target: " + _percentText(profile.targetSoc), Graphics.TEXT_JUSTIFY_CENTER);
        lineY += 18;
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY,
            "Max current: " + ChargingLogic.maxCurrentLabel(profile.maxCurrent), Graphics.TEXT_JUSTIFY_CENTER);
        lineY += 18;

        var nextTime = profile.nextChargingTime;
        if (nextTime != null) {
            dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "Next: " + nextTime, Graphics.TEXT_JUSTIFY_CENTER);
            lineY += 18;
        }

        if (profile.timerLines.size() == 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "No enabled timers", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var timerCount = profile.timerLines.size();
        if (timerCount > 3) {
            timerCount = 3; // fits below the fixed lines above without crowding
        }
        for (var i = 0; i < timerCount; i += 1) {
            dc.drawText(centerX, lineY, Graphics.FONT_XTINY, profile.timerLines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
            lineY += 16;
        }
    }

    function _percentText(value as Number?) as String {
        if (value == null) {
            return "—";
        }
        return value.toString() + "%";
    }

    function _shorten(text as String) as String {
        if (text.length() > 36) {
            return text.substring(0, 36) as String;
        }
        return text;
    }

}

// BehaviorDelegate, back untouched: leaving this screen needs nothing
// beyond the default pop.
class ChargingProfilesDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WeakReference;

    function initialize(view as ChargingProfilesView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onNextPage() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.nextPage();
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.previousPage();
        }
        return true;
    }

    function _resolve() as ChargingProfilesView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ChargingProfilesView?;
    }

}
