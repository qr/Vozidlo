import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// US-023: the charging session detail screen (Night Panel C3, PoC
// NC.detail). Opened through ChargingScreen.open(), from above (D2: its own
// screen, not a Status page).
//
// This does NOT reuse the Status charging page: Cache.mc's _projectCharging
// never stores fullyChargedAt or batteryCareModeTargetValueInPercent (they
// are not part of what fits the 8 KB Storage budget for a page that mostly
// exists to show state of charge at a glance, see model/Cache.mc), so this
// screen needs its own live fetch and reads those two fields off the raw
// response itself. Everything else it shows DOES come through
// VehicleState.parse(), reused rather than re-derived.
class ChargingDetailView extends WatchUi.View {

    private var _hasSection as Boolean = false;
    private var _state as String? = null;
    private var _chargeType as String? = null;
    private var _powerKw as Object? = null;
    private var _remainingMinutes as Object? = null;
    private var _socPercent as Object? = null;
    private var _rangeMeters as Object? = null;
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
    // (ChargingLimitMenuDelegate, ChargingModeMenuDelegate): a picked row
    // closes its menu immediately, so there is nowhere on that transient
    // screen left to show "Command sent" or a refusal by the time either
    // arrives.
    private var _statusMessage as String? = null;
    private var _statusKind as Symbol = :sent;

    function initialize() {
        View.initialize();
    }

    // Public: called by the limit and mode menus once they have popped back
    // here, and available to any future sub-screen that needs the same
    // "report on the screen you actually returned to" pattern.
    function setStatus(message as String, isError as Boolean) as Void {
        _statusMessage = message;
        _statusKind = isError ? :error : :sent;
        WatchUi.requestUpdate();
    }

    // CommandChecker's report on a charge limit or mode change: the car's
    // own word, in its own kind (:sent, :warn or :age, never red). The read
    // refreshed the cache, so the limit and mode shown are reloaded from it.
    function commandChecked(text as String, kind as Symbol) as Void {
        _loadFromCache();
        _statusMessage = text;
        _statusKind = kind;
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {
    }

    // Cached values first (instant, the same "cached data or none" rule as
    // Status for US-013), refined by a live fetch once the user asks for one
    // via the action list (see refresh() below): never re-loaded on every
    // re-entry, so a live refresh already in _fullyChargedAtEpoch/etc. is
    // never clobbered by Cache's narrower shape. Theme per onShow (A21).
    function onShow() as Void {
        Theme.refresh();
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
        _applyValues(charging);
        _sectionAge = Cache.sectionAge("charging");
    }

    // ------------------------------------------------------------ input

    // Same disabled-preconditions as the Status refresh (US-012/US-013/
    // US-040, Refusal): nothing is sent, and the reason is returned so the
    // action list can toast it as Status does; a Refresh that changes
    // nothing on screen would otherwise look broken. :ok when it went out.
    function refresh() as Symbol {
        var verdict = Refusal.current(_fetching);
        if (verdict != :ok) {
            return verdict;
        }
        var settings = getApp().getSettings();

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
        return :ok;
    }

    function _onVehicleResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _fetching = false;

        if (responseCode == 200) {
            var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
            if (body != null) {
                var vehicle = body.get("vehicle") as Dictionary?;
                if (vehicle != null) {
                    var errors = body.get("errors") as Array?;
                    // Persist first, project second: same ordering Status
                    // uses, for the same reason (a crash in one can never
                    // leave the other out of sync).
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
        // No character cap any more: the status line fits by pixels (A5).
        _lastError = ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text;
        WatchUi.requestUpdate();
    }

    function _applySection(section as VehicleState.Section) as Void {
        if (!section.isPresent()) {
            _hasSection = false;
            return;
        }
        _applyValues(section.values);
        _sectionAge = section.age;
    }

    // Cache's projection and VehicleState's values share these keys, so one
    // reader serves both the cached and the live path.
    function _applyValues(values as Dictionary) as Void {
        _hasSection = true;
        _state = values.get("state") as String?;
        _chargeType = values.get("chargeType") as String?;
        _powerKw = values.get("powerKw");
        _remainingMinutes = values.get("remainingMinutes");
        _socPercent = values.get("batterySocPercent");
        _rangeMeters = values.get("rangeMeters");
        _targetSocPercent = values.get("targetSocPercent") as Number?;
        _preferredChargeMode = values.get("preferredChargeMode") as String?;
        _availableChargeModes = values.get("availableChargeModes") as Array<String>?;
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

    // US-024: the limit endpoint has no "unavailable" signal of its own to
    // hide behind (unlike charge mode, see canOpenMode() below); a car that
    // refuses it says so through the command's own negative-transport-code
    // path (see ChargingLimitMenu.mc).
    function openLimit() as Void {
        ChargingLimitMenu.push(self, _targetSocPercent, _batteryCareTarget);
    }

    // US-025: never pushed at all when availableChargeModes is empty, so
    // there is no menu item that can only fail.
    function openMode() as Void {
        var modes = _availableChargeModes;
        if (modes == null || modes.size() == 0) {
            return;
        }
        var menu = ChargingModeMenu.build(modes as Array<String>, _preferredChargeMode);
        WatchUi.pushView(menu, new ChargingModeMenuDelegate(self), Theme.SLIDE_IN);
    }

    // US-026 (Could): always reachable from the menu. Whether profiles are
    // actually supported can only be known by fetching them (see
    // ChargingProfilesView.mc's own comment), which is exactly why that
    // fetch is deferred to when that screen opens, not to whether the menu
    // item appears.
    function openProfiles() as Void {
        var view = new ChargingProfilesView();
        WatchUi.pushView(view, new ChargingProfilesDelegate(view), Theme.SLIDE_IN);
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

    // The charging action list (B6), opened by START and MENU alike. The
    // gating is the same as before the Night Panel: limit behind its
    // operation, mode only with modes to offer, profiles always.
    function openMenu() as Void {
        var menu = new NightMenu("Charging", 0, null);
        menu.addItem(new NightMenuItem("refresh", "Refresh", null, :refresh, null));
        if (canOpenLimit()) {
            var target = _targetSocPercent;
            menu.addItem(new NightMenuItem("limit", "Set charge limit",
                target != null ? target.toString() + "%" : null, :battery, null));
        }
        if (canOpenMode()) {
            menu.addItem(new NightMenuItem("mode", "Set charge mode", _modeSubLabel(), :bolt, null));
        }
        menu.addItem(new NightMenuItem("profiles", "Charging profiles", null, :list, null));
        WatchUi.pushView(menu, new ChargingActionMenuDelegate(self), Theme.SLIDE_IN);
    }

    function _modeSubLabel() as String? {
        var mode = _preferredChargeMode;
        return (mode != null) ? Labels.mode(mode) : null;
    }

    // -------------------------------------------------------- rendering

    // PoC NC.detail: ring with the limit tick, title y 34, hero numMed y 58,
    // state chip y 134, up to two xtiny rows from y 160, age y 202.
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        var cx = dc.getWidth() / 2;

        var soc = ChargingFormat.toNumber(_socPercent);
        var target = _targetSocPercent;
        Bezel.ring(dc, soc != null ? soc / 100.0 : 0,
            _isActive() ? Theme.ACCENT : Theme.TEXT_1,
            (_hasSection && target != null) ? target / 100.0 : null);
        Ui.title(dc, "Charging", 34);
        // START opens the action list; a glyph, not a text hint (B4), and no
        // hint arc because it would sit on the ring.
        Bezel.glyph(dc, Bezel.BTN_START, :menu, Theme.TEXT_1, null);

        if (!_hasSection) {
            _drawNoData(dc, cx);
            return;
        }

        Ui.drawValueWithUnit(dc, cx, 58, soc != null ? soc.toString() + "%" : Labels.DASH, null,
            Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_MEDIUM, Theme.TEXT_1);

        var chip = _stateChip();
        if (chip != null) {
            Chips.draw(dc, cx, 134, chip);
        }

        var rows = ChargingFormat.detailRows(_powerKw, _chargeType, _fullyChargedAtEpoch,
            _remainingMinutes, _rangeMeters, ChargingFormat.MAX_DETAIL_ROWS);
        var rowsBottom = ChargingFormat.drawLines(dc, 160, ChargingFormat.ROW_PITCH, rows, Theme.TEXT_1);

        // A transient line (offline, refreshing, an error, command feedback)
        // takes a free row slot so the age stays visible; with both rows in
        // use it replaces the age until the next refresh.
        var kind = _transientKind();
        if (kind != null && rows.size() < ChargingFormat.MAX_DETAIL_ROWS) {
            Ui.drawStatusLine(dc, rowsBottom, _transientText(), kind);
            _drawAge(dc, 202);
        } else if (kind != null) {
            Ui.drawStatusLine(dc, 202, _transientText(), kind);
        } else {
            _drawAge(dc, 202);
        }
    }

    // PoC NS.page nodata: "No data yet", then a hint where the age goes.
    function _drawNoData(dc as Dc, cx as Number) as Void {
        var font = Graphics.FONT_SMALL;
        var y = 98;
        var s = Ui.fit("No data yet", Ui.usable(y, y + dc.getFontHeight(font), Theme.RING_MARGIN), Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
        var kind = _transientKind();
        if (kind != null) {
            Ui.drawStatusLine(dc, 136, _transientText(), kind);
        } else {
            Ui.drawStatusLine(dc, 136, "Refresh from the menu", :age);
        }
    }

    function _isActive() as Boolean {
        var state = _state;
        return state != null && state.equals("CHARGING");
    }

    // US-022: CONNECT_CABLE is the state under which starting is still
    // offered but must be accompanied by a warning; shown here as the amber
    // "! Plug in" chip for as long as it applies. States without a chip of
    // their own (discharging, values this app has never seen) still get an
    // outline chip with the humanised word: on this screen the state is the
    // point, not an optional extra.
    function _stateChip() as Chips.Chip? {
        var state = _state;
        if (state == null) {
            return null;
        }
        if (ChargingLogic.needsCableWarning(state)) {
            return new Chips.Chip(Labels.charging(state), null, :warn);
        }
        var chip = Chips.forCharging(state);
        if (chip != null) {
            return chip;
        }
        return new Chips.Chip(Labels.charging(state), null, :outline);
    }

    // Priority: phone offline, refreshing, the last fetch error, then the
    // feedback a sub-menu reported via setStatus(). null = nothing transient.
    function _transientKind() as Symbol? {
        if (!(System.getDeviceSettings().phoneConnected)) {
            return :error;
        }
        if (_fetching) {
            return :age;
        }
        if (_lastError != null) {
            return :error;
        }
        if (_statusMessage != null) {
            return _statusKind;
        }
        return null;
    }

    function _transientText() as String {
        if (!(System.getDeviceSettings().phoneConnected)) {
            return Commands.NO_PHONE;
        }
        if (_fetching) {
            return "Refreshing" + Labels.ELLIPSIS;
        }
        var error = _lastError;
        if (error != null) {
            return error;
        }
        var message = _statusMessage;
        return message != null ? message : "";
    }

    // A19/US-009: the charging age gets the same amber "! 17 h ago" as every
    // other section once it is stale.
    function _drawAge(dc as Dc, y as Number) as Void {
        var seconds = Age.elapsed(_sectionAge, Time.now().value());
        var kind = (seconds != null && Age.isStale(seconds)) ? :warn : :age;
        Ui.drawStatusLine(dc, y, Age.line(seconds), kind);
    }

    // Duplicated small ISO-8601 parser, see model/VehicleState.mc's own
    // comment on why this exact, small, already-tested shape is copied
    // rather than reached for across an ownership boundary (this screen
    // owns no file in model/).
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

// BehaviorDelegate, never InputDelegate; back untouched. START and MENU both
// open the action list (B6): there is one list of things to do here, and
// MENU is a long-press UP on these watches, which few people find.
class ChargingDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WeakReference;

    function initialize(view as ChargingDetailView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onSelect() as Boolean {
        return _openMenu();
    }

    function onMenu() as Boolean {
        return _openMenu();
    }

    // A15: a tap never refreshes (a refresh costs quota, and a tap is easy
    // to make by accident). It opens the same list START does, so touch
    // users still reach the actions; handled here so it never also arrives
    // as onSelect.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return _openMenu();
    }

    function _openMenu() as Boolean {
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

// The rows ChargingDetailView.openMenu() builds. Pops before acting (A14),
// so Refresh shows its progress on the detail screen and a sub-menu is
// pushed onto the detail screen rather than onto this list. String ids: a
// string is as comparable as a Symbol, so there is no second, parallel
// Symbol table that could drift from the labels.
class ChargingActionMenuDelegate extends NightMenuDelegate {

    private var _view as WeakReference;

    function initialize(view as ChargingDetailView) {
        NightMenuDelegate.initialize(true);
        _view = view.weak();
    }

    function onPick(id as Object?) as Void {
        var view = _resolve();
        if (view == null || !(id instanceof String)) {
            return;
        }
        var key = id as String;
        if (key.equals("refresh")) {
            Refusal.toast(Refusal.text(view.refresh(), Quota.secondsUntilReset()));
        } else if (key.equals("limit")) {
            view.openLimit();
        } else if (key.equals("mode")) {
            view.openMode();
        } else if (key.equals("profiles")) {
            view.openProfiles();
        }
    }

    function _resolve() as ChargingDetailView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ChargingDetailView?;
    }

}
