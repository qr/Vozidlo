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

    // xtiny pitch on the profile card (PoC NC.profile) and the lowest line
    // start that still leaves a usable chord.
    const LINE_PITCH = 19;
    const LAST_LINE_Y = 216;

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
        Theme.refresh();
        if (!_hasFetched) {
            _fetch();
        }
    }

    function _fetch() as Void {
        if (_fetching) {
            return;
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            _lastError = Commands.NO_PHONE;
            WatchUi.requestUpdate();
            return;
        }
        if (!Quota.canSpend()) {
            _lastError = Commands.QUOTA_SPENT;
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
        // No character cap: the error line fits by pixels (A5).
        _lastError = ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text;
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
                timerLines.add((time != null ? time : Labels.DASH) + " " + recurrence);
            }
        }

        return new ChargingProfileEntry(
            (name != null) ? name : Labels.DASH, targetSoc, maxCurrent, isCurrent,
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

    // A19: SELECT retries after a failed or blocked fetch. A loaded list is
    // not re-fetched: profiles are fetched once per visit (class comment).
    function retry() as Void {
        if (_fetching || (_hasFetched && _lastError == null)) {
            return;
        }
        _fetch();
    }

    // -------------------------------------------------------- rendering

    // PoC NC.profile / NC.profilesUnsupported: title y 40, then either a
    // state (loading, error, unsupported, none) or one profile card.
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        Ui.title(dc, "Charging profiles", 40);

        if (_fetching) {
            _drawState(dc, "Loading" + Labels.ELLIPSIS, null);
            return;
        }

        var error = _lastError;
        if (error != null) {
            Ui.drawStatusLine(dc, 112, error, :error);
            _drawRetryGlyph(dc);
            return;
        }

        if (!_hasFetched) {
            // Only when the config gate blocked the fetch; START tries again.
            _drawState(dc, "Not loaded", null);
            _drawRetryGlyph(dc);
            return;
        }

        if (!_supported) {
            // US-026: "the section is absent". This vehicle simply does
            // not have any (the mock's default scenario, and every real
            // vehicle measured so far, see mock/README.md).
            _drawState(dc, "Not supported", "by this car");
            return;
        }

        if (_profiles.size() == 0) {
            _drawState(dc, "No profiles saved", null);
            return;
        }

        _drawProfile(dc, _profiles[_pageIndex] as ChargingProfileEntry);
        if (_profiles.size() > 1) {
            Bezel.pageDots(dc, _pageIndex, _profiles.size());
        }
    }

    // FONT_SMALL at y 104, an optional grey second line at y 136.
    function _drawState(dc as Dc, line1 as String, line2 as String?) as Void {
        var font = Graphics.FONT_SMALL;
        var cx = dc.getWidth() / 2;
        var h = dc.getFontHeight(font);
        var measure = Ui.measurer(dc, font);
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 104, font, Ui.fit(line1, Ui.usable(104, 104 + h, Theme.MARGIN), measure), Graphics.TEXT_JUSTIFY_CENTER);
        if (line2 != null) {
            dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 136, font, Ui.fit(line2, Ui.usable(136, 136 + h, Theme.MARGIN), measure), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Replaces the old "SELECT to load" text: a glyph at START (B4).
    function _drawRetryGlyph(dc as Dc) as Void {
        Bezel.glyph(dc, Bezel.BTN_START, :refresh, Theme.TEXT_1, :accent);
    }

    // Name as the hero word y 70, a white "Here" chip y 108 for the profile
    // where the car is parked (A-resolutions: white, not green), facts from
    // y 136, timers in grey below them, each line fitted to its chord.
    function _drawProfile(dc as Dc, profile as ChargingProfileEntry) as Void {
        var cx = dc.getWidth() / 2;
        var font = Graphics.FONT_MEDIUM;
        var nameY = 70;
        var name = Ui.fit(profile.name, Ui.usable(nameY, nameY + dc.getFontHeight(font), Theme.MARGIN), Ui.measurer(dc, font));
        Ui.drawHeroWord(dc, cx, nameY, name, null, Theme.TEXT_1);

        if (profile.isCurrent) {
            Chips.draw(dc, cx, 108, new Chips.Chip("Here", :pin, :white));
        }

        var facts = [
            "Target " + _percentText(profile.targetSoc),
            "Max current " + Labels.maxCurrent(profile.maxCurrent).toLower()
        ] as Array<String>;
        var nextTime = profile.nextChargingTime;
        if (nextTime != null) {
            facts.add("Next " + nextTime);
        }
        var y = ChargingFormat.drawLines(dc, 136, LINE_PITCH, facts, Theme.TEXT_1);

        // Timers start at y 178 (PoC) or right under a third fact line; the
        // last one must start by y 216, where the chord is still ~130 px.
        var timerY = y + 4 > 178 ? y + 4 : 178;
        if (profile.timerLines.size() == 0) {
            ChargingFormat.drawLines(dc, timerY, LINE_PITCH, ["No enabled timers"] as Array<String>, Theme.TEXT_2);
            return;
        }
        var room = (LAST_LINE_Y - timerY) / LINE_PITCH + 1;
        var timers = profile.timerLines;
        if (timers.size() > room) {
            timers = timers.slice(0, room) as Array<String>;
        }
        ChargingFormat.drawLines(dc, timerY, LINE_PITCH, timers, Theme.TEXT_2);
    }

    function _percentText(value as Number?) as String {
        if (value == null) {
            return Labels.DASH;
        }
        return value.toString() + "%";
    }

}

// BehaviorDelegate, back untouched: leaving this screen needs nothing
// beyond the default pop. UP/DOWN page through the profiles; SELECT retries
// a failed fetch (A19), which the old delegate could not do at all.
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

    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.retry();
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
