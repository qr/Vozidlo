import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// US-023: the charging session detail screen. Reached from ControlsView via
// UP (ControlsDelegate.onPreviousPage(), added alongside task 6's existing
// DOWN -> StatusView): "a screen below the tile" from
// docs/requirements.md US-023, read as "one more press away, vertically",
// exactly the pattern StatusView already established rather than a second,
// competing navigation scheme.
//
// This does NOT reuse StatusView's own "charging" page: Cache.mc's
// _projectCharging never stores fullyChargedAt or
// batteryCareModeTargetValueInPercent (they are not part of what fits the
// 8 KB Storage budget for a page that mostly exists to show state of charge
// at a glance, see model/Cache.mc), so this screen needs its own live
// fetch and reads those two fields off the raw response itself. Everything
// else it shows DOES come through VehicleState.parse(), reused rather than
// re-derived.
class ChargingDetailView extends WatchUi.View {

    private var _hasSection as Boolean = false;
    private var _state as String? = null;
    private var _chargeType as String? = null;
    private var _powerKw as Object? = null;
    private var _rateKmH as Object? = null;
    private var _remainingMinutes as Object? = null;
    private var _targetSocPercent as Number? = null;
    private var _preferredChargeMode as String? = null;
    private var _availableChargeModes as Array<String>? = null;
    private var _sectionAge as Number? = null;

    // Only ever populated by a live response (see the class comment above):
    // never guessed from Cache, so null here honestly means "not fetched
    // this session yet", not "the car has none".
    private var _fullyChargedAtEpoch as Number? = null;
    private var _batteryCareTarget as Number? = null;

    private var _operations as Array<String>? = null;

    private var _fetching as Boolean = false;
    private var _lastError as String? = null;

    // Set by a sub-screen reporting back after it has already popped itself
    // (see ChargingModeMenuDelegate.setStatus() calls): a Menu2 selection
    // closes immediately, so there is nowhere on that transient screen left
    // to show "Command sent" or a refusal by the time either arrives.
    private var _statusMessage as String? = null;
    private var _statusIsError as Boolean = false;

    function initialize() {
        View.initialize();
    }

    // Public: called by ChargingModeMenuDelegate once it has popped back
    // here, and available to any future sub-screen that needs the same
    // "report on the screen you actually returned to" pattern.
    function setStatus(message as String, isError as Boolean) as Void {
        _statusMessage = message;
        _statusIsError = isError;
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {
    }

    // Cached values first (instant, matches StatusView's own "cached data or
    // none" rule for US-013), refined by a live fetch once the user asks for
    // one via SELECT (see refresh() below): never re-loaded on every
    // re-entry, so a live refresh already in _fullyChargedAtEpoch/etc. is
    // never clobbered by Cache's narrower shape.
    function onShow() as Void {
        if (!_hasSection) {
            _loadFromCache();
        }
    }

    function _loadFromCache() as Void {
        var charging = Cache.section("charging");
        _operations = Cache.operations() as Array<String>?;
        if (charging == null) {
            return;
        }
        _hasSection = true;
        _state = charging.get("state") as String?;
        _chargeType = charging.get("chargeType") as String?;
        _powerKw = charging.get("powerKw");
        _rateKmH = charging.get("rateKmH");
        _remainingMinutes = charging.get("remainingMinutes");
        _targetSocPercent = charging.get("targetSocPercent") as Number?;
        _preferredChargeMode = charging.get("preferredChargeMode") as String?;
        _availableChargeModes = charging.get("availableChargeModes") as Array<String>?;
        _sectionAge = Cache.sectionAge("charging");
    }

    // ------------------------------------------------------------ input

    // Same disabled-preconditions as StatusView.refresh()/ControlsView.
    // activate() (US-012/US-013/US-040): silently do nothing rather than
    // fail loudly, because the top bar already explains why.
    function refresh() as Void {
        if (_fetching) {
            return;
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            return;
        }
        if (!Quota.canSpend()) {
            return;
        }
        var settings = getApp().getSettings();
        if (!settings.vinValid || settings.apiKey.length() == 0) {
            return;
        }

        _fetching = true;
        _lastError = null;
        _statusMessage = null;
        WatchUi.requestUpdate();
        // "operations" alongside "charging": same request, same quota cost
        // (docs/best-practices measured this: narrowing `include` reduces
        // what there is to parse, not what a read costs), and this screen's
        // own limit/mode actions need a fresh capability list to gate on
        // (see canOpenLimit()/canOpenMode() below).
        ApiClient.getVehicle(settings.vin, "charging,operations", settings.apiKey, method(:_onVehicleResponse));
    }

    function _onVehicleResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _fetching = false;

        if (responseCode == 200) {
            var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
            if (body != null) {
                var vehicle = body.get("vehicle") as Dictionary?;
                if (vehicle != null) {
                    var errors = body.get("errors") as Array?;
                    // Persist first, project second: same ordering
                    // StatusView uses, for the same reason (a crash in one
                    // can never leave the other out of sync).
                    Cache.update(vehicle, errors);
                    var parsed = VehicleState.parse(vehicle, errors);
                    _applySection(parsed.charging);
                    _operations = parsed.operations;
                    _applyRawExtras(vehicle.get("charging") as Dictionary?);
                    _lastError = null;
                }
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

    function _applySection(section as VehicleState.Section) as Void {
        if (!section.isPresent()) {
            _hasSection = false;
            return;
        }
        _hasSection = true;
        var values = section.values;
        _state = values.get("state") as String?;
        _chargeType = values.get("chargeType") as String?;
        _powerKw = values.get("powerKw");
        _rateKmH = values.get("rateKmH");
        _remainingMinutes = values.get("remainingMinutes");
        _targetSocPercent = values.get("targetSocPercent") as Number?;
        _preferredChargeMode = values.get("preferredChargeMode") as String?;
        _availableChargeModes = values.get("availableChargeModes") as Array<String>?;
        _sectionAge = section.age;
    }

    // fullyChargedAt / batteryCareModeTargetValueInPercent: see the class
    // comment, not part of VehicleState's projection, read directly off the
    // raw section this live response carried.
    function _applyRawExtras(raw as Dictionary?) as Void {
        if (raw == null) {
            return;
        }
        var status = raw.get("status") as Dictionary?;
        var fullyChargedAt = (status != null) ? (status.get("fullyChargedAt") as String?) : null;
        _fullyChargedAtEpoch = (fullyChargedAt != null) ? _parseIso8601(fullyChargedAt) : null;

        var settings = raw.get("settings") as Dictionary?;
        _batteryCareTarget = (settings != null) ? (settings.get("batteryCareModeTargetValueInPercent") as Number?) : null;
    }

    // -------------------------------------------------------- sub-screens

    // US-024: always reachable. The limit endpoint has no "unavailable"
    // signal of its own to hide behind (unlike charge mode, see
    // canOpenMode() below); a car that refuses it says so through the
    // command's own negative-transport-code path (see ChargingLimitView.mc).
    function openLimit() as Void {
        var view = new ChargingLimitView(_targetSocPercent, _batteryCareTarget);
        WatchUi.pushView(view, new ChargingLimitDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // US-025: the whole point of this task's "trust availableChargeModes,
    // not operations[]" rule: never pushed at all when the array is empty,
    // so there is no menu item that can only fail.
    function openMode() as Void {
        var modes = _availableChargeModes;
        if (modes == null || modes.size() == 0) {
            return;
        }
        var menu = ChargingModeMenu.build(modes as Array<String>, _preferredChargeMode);
        WatchUi.pushView(menu, new ChargingModeMenuDelegate(self), WatchUi.SLIDE_LEFT);
    }

    // US-026 (Could): always reachable from the menu. Whether profiles are
    // actually supported can only be known by fetching them (see
    // ChargingProfilesView.mc's own comment), which is exactly why that
    // fetch is deferred to when this screen opens, not to whether the menu
    // item appears.
    function openProfiles() as Void {
        var view = new ChargingProfilesView();
        WatchUi.pushView(view, new ChargingProfilesDelegate(view), WatchUi.SLIDE_LEFT);
    }

    function canOpenLimit() as Boolean {
        return _hasOperation("setChargingLimit");
    }

    function canOpenMode() as Boolean {
        return ChargingLogic.modeActionVisible(_availableChargeModes, _hasOperation("setChargeMode"));
    }

    // Duplicated from ControlTiles._hasOperation rather than shared across
    // files: Monkey C modules have no `private` (see Cache.mc's own
    // comment on the same limitation), and this is a small, already-tested
    // shape with nothing else in common with that module's tile-building.
    function _hasOperation(name as String) as Boolean {
        var ops = _operations;
        if (ops == null) {
            return true; // US-014: unknown means "assume possibly supported"
        }
        for (var i = 0; i < ops.size(); i += 1) {
            if ((ops[i] as String).equals(name)) {
                return true;
            }
        }
        return false;
    }

    function openMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Charging" });
        menu.addItem(new WatchUi.MenuItem("Refresh", null, "refresh", null));
        if (canOpenLimit()) {
            menu.addItem(new WatchUi.MenuItem("Set charge limit", null, "limit", null));
        }
        if (canOpenMode()) {
            menu.addItem(new WatchUi.MenuItem("Set charge mode", _modeSubLabel(), "mode", null));
        }
        menu.addItem(new WatchUi.MenuItem("Charging profiles", null, "profiles", null));
        WatchUi.pushView(menu, new ChargingActionMenuDelegate(self), WatchUi.SLIDE_LEFT);
    }

    function _modeSubLabel() as String? {
        var mode = _preferredChargeMode;
        return (mode != null) ? ChargingLogic.modeLabel(mode) : null;
    }

    // -------------------------------------------------------- rendering

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var centerX = dc.getWidth() / 2;
        _drawTopBar(dc, centerX);

        if (!_hasSection) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL, "No charging data yet", Graphics.TEXT_JUSTIFY_CENTER);
            _drawStatus(dc, centerX, 160);
            _drawBottomBar(dc, centerX, dc.getHeight());
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 60, Graphics.FONT_MEDIUM, ChargingLogic.stateLabel(_state), Graphics.TEXT_JUSTIFY_CENTER);

        // US-022: the state under which starting is still offered but must
        // be accompanied by a warning: shown here too, not only at the
        // moment of pressing Start on ControlsView, so the reason is visible
        // for as long as it applies, not just for one status line.
        if (ChargingLogic.needsCableWarning(_state)) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 84, Graphics.FONT_XTINY, "No cable appears to be connected", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var lineY = 110;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "Type: " + ChargingLogic.chargeTypeLabel(_chargeType), Graphics.TEXT_JUSTIFY_CENTER);
        lineY += 18;
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "Power: " + _numberText(_powerKw, " kW"), Graphics.TEXT_JUSTIFY_CENTER);
        lineY += 18;
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "Rate: " + _numberText(_rateKmH, " km/h"), Graphics.TEXT_JUSTIFY_CENTER);
        lineY += 18;
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "Remaining: " + _numberText(_remainingMinutes, " min"), Graphics.TEXT_JUSTIFY_CENTER);
        lineY += 18;
        dc.drawText(centerX, lineY, Graphics.FONT_XTINY, "Full by: " + _fullyChargedAtText(), Graphics.TEXT_JUSTIFY_CENTER);

        _drawStatus(dc, centerX, 196);
        _drawAge(dc, centerX, 214);
        _drawBottomBar(dc, centerX, dc.getHeight());
    }

    // "Command sent" / "Vehicle refused: ..." reported by a sub-screen that
    // has already popped back here, see setStatus() and the class comment
    // on _statusMessage above.
    function _drawStatus(dc as Dc, centerX as Number, y as Number) as Void {
        var message = _statusMessage;
        if (message == null) {
            return;
        }
        dc.setColor(_statusIsError ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_XTINY, message as String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawTopBar(dc as Dc, centerX as Number) as Void {
        if (!(System.getDeviceSettings().phoneConnected)) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 12, Graphics.FONT_XTINY, "Phone not connected", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (_fetching) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 12, Graphics.FONT_XTINY, "Refreshing...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (_lastError != null) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 12, Graphics.FONT_XTINY, _lastError as String, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 12, Graphics.FONT_XTINY, "CHARGING", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawBottomBar(dc as Dc, centerX as Number, height as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height - 20, Graphics.FONT_XTINY, "SELECT refresh - MENU actions", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawAge(dc as Dc, centerX as Number, y as Number) as Void {
        var age = _sectionAge;
        if (age == null) {
            return;
        }
        var ageSeconds = Time.now().value() - age;
        if (ageSeconds < 0) {
            ageSeconds = 0;
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Graphics.FONT_XTINY, _ageText(ageSeconds), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _ageText(seconds as Number) as String {
        if (seconds < 60) {
            return "Updated just now";
        }
        var minutes = seconds / 60;
        if (minutes < 60) {
            return minutes.toString() + " min ago";
        }
        var hours = minutes / 60;
        return hours.toString() + "h ago";
    }

    // US-023: fullyChargedAt as a local clock time, the same way
    // ProblemDetail._formatClock() already renders a Retry-After deadline:
    // reused as a pattern, not as code (ProblemDetail's version is not
    // exposed for reuse, and this one has its own epoch source).
    function _fullyChargedAtText() as String {
        var epoch = _fullyChargedAtEpoch;
        if (epoch == null) {
            return "—";
        }
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return _pad2(info.hour) + ":" + _pad2(info.min);
    }

    function _pad2(n as Number) as String {
        if (n < 10) {
            return "0" + n.toString();
        }
        return n.toString();
    }

    function _numberText(value as Object?, suffix as String) as String {
        if (value == null) {
            return "—";
        }
        if (value instanceof Float) {
            return (value as Float).format("%.1f") + suffix;
        }
        return value.toString() + suffix;
    }

    function _shorten(text as String) as String {
        if (text.length() > 36) {
            return text.substring(0, 36) as String;
        }
        return text;
    }

    // Duplicated small ISO-8601 parser, see model/VehicleState.mc's own
    // comment on why this exact, small, already-tested shape is copied
    // rather than reached for across an ownership boundary (this task owns
    // no file in model/).
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

// BehaviorDelegate, never InputDelegate. Back untouched. SELECT refreshes
// (matches StatusView's own convention); MENU opens this screen's actions
// (US-024/US-025/US-026) rather than crowding SELECT with a long-press or a
// second confirmation scheme: docs/best-practices' Menu2 guidance.
class ChargingDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WeakReference;

    function initialize(view as ChargingDetailView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.refresh();
        }
        return true;
    }

    function onMenu() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.openMenu();
        }
        return true;
    }

    function _resolve() as ChargingDetailView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ChargingDetailView?;
    }

}

// The four items ChargingDetailView.openMenu() builds. String ids (not
// Symbol): WatchUi.MenuItem's identifier is declared as a plain Object,
// and a string is exactly as comparable, so there is no need for a second,
// parallel Symbol table that could drift from the labels above it.
class ChargingActionMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WeakReference;

    function initialize(view as ChargingDetailView) {
        Menu2InputDelegate.initialize();
        _view = view.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String?;
        var view = _resolve();
        if (view == null || id == null) {
            return;
        }
        if (id.equals("refresh")) {
            view.refresh();
        } else if (id.equals("limit")) {
            view.openLimit();
        } else if (id.equals("mode")) {
            view.openMode();
        } else if (id.equals("profiles")) {
            view.openProfiles();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function _resolve() as ChargingDetailView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ChargingDetailView?;
    }

}
