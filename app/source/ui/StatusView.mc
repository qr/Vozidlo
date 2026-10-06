import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.PersistedContent;

// The detailed status screen (US-008 through US-015). One page per section
// (status/lock, fuel & range, charging, odometer, air conditioning),
// navigated vertically per docs/best-practices ("up/down page loops map to
// both buttons and touch; left/right does not map well to physical
// buttons"): the "at a glance" single screen with no scrolling is task 7's
// landing screen; this is the "one press below" detailed view the task
// brief describes. do not restructure app startup or VozidloApp.mc: getting
// here is wired up once task 7 (or whichever task ends up owning
// getInitialView()) exists, see this task's final report for the exact
// one-line change needed.
//
// Every value shown is read from a VehicleState.Vehicle built either fresh
// from a live response (see _onVehicleResponse below) or, when there is
// nothing live yet, projected out of Cache.mc (US-013: cached values with
// their own age, even with no BLE connection at all). Both paths converge
// on the same VehicleState.Section shape so onUpdate() never needs to know
// which one it is drawing.
class StatusView extends WatchUi.View {

    // Order they are offered to the user; also the order operations[]-style
    // capability checks would apply once task 7 adds real commands.
    private var _pageKeys as Array<String> = ["status", "fuelStatus", "charging", "odometer", "airConditioning"];
    private var _visiblePageKeys as Array<String> = ["status"];
    private var _pageIndex as Number = 0;

    private var _vehicle as VehicleState.Vehicle? = null;
    private var _fetching as Boolean = false;
    // Set on any non-200/429 failure so the top bar can say something
    // without ever touching _vehicle: a failed refresh must never blank or
    // stale-overwrite what is already on screen (US-013/US-015).
    private var _lastError as String? = null;

    function initialize() {
        View.initialize();
    }

    // No custom fonts or bitmaps to load: every draw call below uses a
    // built-in Graphics font, so there is nothing this needs beyond the
    // default View.onLayout(). Kept only because deriving from View, and
    // present so a reviewer does not have to go looking for it.
    function onLayout(dc as Dc) as Void {
    }

    // Cache.mc is Storage-backed and effectively instant, so pulling the
    // last known state here is "parse once when a response lands" (the
    // response just landed a while ago, is all): never resource loading,
    // and it is what makes the screen show something immediately, even with
    // no BLE connection (US-013). Guarded so a later live refresh (which
    // sets _vehicle itself) is never clobbered by a re-entry into onShow().
    function onShow() as Void {
        if (_vehicle == null) {
            _vehicle = _fromCache();
        }
        _recomputePages();
    }

    // ------------------------------------------------------------- input

    // Called by StatusDelegate.onSelect(). Every early return here is a
    // case US-012/US-013 requires the action to be "visibly disabled rather
    // than failing when pressed": the top bar already shows why (phone not
    // connected, quota spent, or mid-refresh), so silently doing nothing is
    // the correct behaviour, not a bug.
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
            // Nothing sensible to request yet: guiding the user through
            // that is the onboarding screen's job (US-002/US-003), not this
            // one's.
            return;
        }

        _fetching = true;
        _lastError = null;
        WatchUi.requestUpdate();

        // Only the sections this screen draws: same quota cost as the
        // unfiltered read, less to parse and hold (US-008's note).
        ApiClient.getVehicle(settings.vin, "status,charging,fuelStatus,odometer,airConditioning", settings.apiKey, method(:_onVehicleResponse));
    }

    function nextPage() as Void {
        if (_visiblePageKeys.size() == 0) {
            return;
        }
        _pageIndex = (_pageIndex + 1) % _visiblePageKeys.size();
        WatchUi.requestUpdate();
    }

    function previousPage() as Void {
        if (_visiblePageKeys.size() == 0) {
            return;
        }
        _pageIndex = (_pageIndex - 1 + _visiblePageKeys.size()) % _visiblePageKeys.size();
        WatchUi.requestUpdate();
    }

    // -------------------------------------------------------- networking

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
                    _recomputePages();
                    _lastError = null;
                }
            }
            // A 200 proves this request was not actually being held back:
            // clears a stale Retry-After gate even with nothing fresh to
            // report, exactly as Quota.recordHeaders()'s own doc comment
            // describes. There is no RateLimit-* to pass: Connect IQ cannot
            // read response headers (see ApiClient.mc): this is the
            // "app's own estimate", not a real reading, and the UI words it
            // that way (see _quotaLabel()).
            Quota.recordHeaders(null, null, null);
            WatchUi.requestUpdate();
            return;
        }

        var errorBody = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (errorBody != null) ? (errorBody.get("type") as String?) : null;
            // Retry-After is likewise an unreadable header on this
            // platform, so this can only ever record "blocked", never
            // "blocked until X", see Quota.mc's own module comment.
            Quota.recordRateLimited(problemType, null);
        }
        _lastError = _shorten(ProblemDetail.describe(responseCode, errorBody, Quota.retryAfterUntil()).text);
        WatchUi.requestUpdate();
    }

    // ------------------------------------------------------- cache path

    // US-013: reconstructs the same VehicleState.Vehicle shape straight out
    // of Cache.mc's compact projection, so onUpdate() has exactly one
    // rendering path regardless of whether the data is fresh or cached.
    // Every section Cache has never seen becomes KIND_UNKNOWN: "no data
    // yet", not "this car doesn't have this" (see VehicleState.KIND_UNKNOWN).
    function _fromCache() as VehicleState.Vehicle {
        var now = Time.now().value();
        return new VehicleState.Vehicle(
            Cache.vin(), Cache.name(), Cache.operations() as Array<String>?,
            _cachedSection("status", now),
            _cachedSection("charging", now),
            _cachedFuelSection(now),
            _cachedSection("odometer", now),
            _cachedSection("airConditioning", now)
        );
    }

    function _cachedSection(key as String, now as Number) as VehicleState.Section {
        var values = Cache.section(key);
        if (values == null) {
            return new VehicleState.Section(VehicleState.KIND_UNKNOWN, null, {});
        }
        return new VehicleState.Section(VehicleState.KIND_PRESENT, Cache.sectionAge(key), values);
    }

    // fuelStatus needs its own path because Cache._projectEngineRange keeps
    // BOTH currentSoCInPercent (as "socPercent") and currentFuelLevelInPercent
    // (as "fuelPercent"): VehicleState's own "percent" resolution (engine
    // type decides which one is meaningful, see VehicleState._engineValues)
    // has to be re-applied here rather than reused, since it is Cache's
    // already-split fields being resolved, not the raw API ones.
    function _cachedFuelSection(now as Number) as VehicleState.Section {
        var raw = Cache.section("fuelStatus");
        if (raw == null) {
            return new VehicleState.Section(VehicleState.KIND_UNKNOWN, null, {});
        }
        var values = {
            "carType" => raw.get("carType"),
            "totalRangeInKm" => raw.get("totalRangeInKm"),
            "primary" => _cachedEngine(raw.get("primary") as Dictionary?),
            "secondary" => _cachedEngine(raw.get("secondary") as Dictionary?)
        };
        return new VehicleState.Section(VehicleState.KIND_PRESENT, Cache.sectionAge("fuelStatus"), values);
    }

    function _cachedEngine(raw as Dictionary?) as Dictionary? {
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

    // ------------------------------------------------------------ paging

    function _sectionFor(key as String) as VehicleState.Section {
        var vehicle = _vehicle;
        if (vehicle == null) {
            return new VehicleState.Section(VehicleState.KIND_UNKNOWN, null, {});
        }
        if (key.equals("status")) {
            return vehicle.status;
        }
        if (key.equals("charging")) {
            return vehicle.charging;
        }
        if (key.equals("fuelStatus")) {
            return vehicle.fuelStatus;
        }
        if (key.equals("odometer")) {
            return vehicle.odometer;
        }
        return vehicle.airConditioning;
    }

    // US-014/US-015: KIND_UNSUPPORTED (an explicit error, or a genuine
    // absence with none, see VehicleState._kindForAbsence) hides a section
    // PERMANENTLY: it never becomes a page. Every other kind
    // (UNAVAILABLE, DISABLED, UNKNOWN, PRESENT) keeps its place, each drawn
    // distinctly by _drawPage()/_kindLabel().
    function _recomputePages() as Void {
        var visible = [] as Array<String>;
        for (var i = 0; i < _pageKeys.size(); i += 1) {
            var key = _pageKeys[i];
            if (!_sectionFor(key).kind.equals(VehicleState.KIND_UNSUPPORTED)) {
                visible.add(key);
            }
        }
        if (visible.size() == 0) {
            visible.add("status"); // never render zero pages
        }
        _visiblePageKeys = visible;
        if (_pageIndex >= _visiblePageKeys.size()) {
            _pageIndex = 0;
        }
    }

    // -------------------------------------------------------- rendering
    //
    // Pre-computed by the time onUpdate() runs, see onShow()/refresh()
    // above, so onUpdate() below only ever draws. See
    // docs/best-practices/garmin-connect-iq.md, "Pre-compute, then draw."

    function onUpdate(dc as Dc) as Void {
        dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        _drawTopBar(dc, width);
        _drawPage(dc, centerX);
        _drawBottomBar(dc, centerX, height);
    }

    function _drawTopBar(dc as Dc, width as Number) as Void {
        var centerX = width / 2;
        dc.setColor(MonochromeTest.color(Graphics.COLOR_DK_GRAY), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 12, Graphics.FONT_XTINY,
            (_pageIndex + 1).toString() + "/" + _visiblePageKeys.size().toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        // US-013: a clear, textual "phone not connected" indicator. Takes
        // priority over quota/refresh state because it explains why every
        // request-making action is disabled.
        if (!(System.getDeviceSettings().phoneConnected)) {
            dc.setColor(MonochromeTest.color(Graphics.COLOR_RED), Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 28, Graphics.FONT_XTINY, "Phone not connected", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_fetching) {
            dc.setColor(MonochromeTest.color(Graphics.COLOR_LT_GRAY), Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 28, Graphics.FONT_XTINY, "Refreshing...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_lastError != null) {
            dc.setColor(MonochromeTest.color(Graphics.COLOR_ORANGE), Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 28, Graphics.FONT_XTINY, _lastError as String, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setColor(MonochromeTest.color(Graphics.COLOR_LT_GRAY), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 28, Graphics.FONT_XTINY, _quotaLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // US-012: worded as an estimate throughout, because that is what it is
    //: Connect IQ cannot read RateLimit-Remaining, so Quota.remaining() is
    // only ever non-null after a previous 429 forced it there (see
    // Quota.mc). "SELECT to refresh" (no number at all) is the honest
    // default state, not a bug.
    function _quotaLabel() as String {
        if (!Quota.canSpend()) {
            var resetSeconds = Quota.secondsUntilReset();
            if (resetSeconds != null) {
                return "Quota spent, resets in ~" + (resetSeconds / 60).toString() + "m";
            }
            return "Quota spent for this hour";
        }
        var remaining = Quota.remaining();
        if (remaining != null) {
            var prefix = Quota.isLow() ? "Low: " : "";
            return prefix + "~" + remaining.toString() + " left (est.)";
        }
        return "SELECT to refresh";
    }

    function _drawPage(dc as Dc, centerX as Number) as Void {
        var key = _visiblePageKeys[_pageIndex] as String;
        var section = _sectionFor(key);

        dc.setColor(MonochromeTest.color(Graphics.COLOR_LT_GRAY), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 56, Graphics.FONT_SMALL, _titleFor(key), Graphics.TEXT_JUSTIFY_CENTER);

        if (!section.isPresent()) {
            dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 100, Graphics.FONT_NUMBER_MEDIUM, EM_DASH, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(MonochromeTest.color(_kindColor(section.kind)), Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 150, Graphics.FONT_SMALL, _kindLabel(section.kind), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var values = section.values;
        var subLines = [] as Array<String>;
        var value = EM_DASH;
        var emphasize = false;

        if (key.equals("status")) {
            var doorsLocked = values.get("doorsLocked") as String?;
            value = _lockLabel(doorsLocked);
            emphasize = _isInsecure(doorsLocked);
            subLines.add("Doors " + _textOr(values.get("doors")));
            var windows = values.get("windows") as String?;
            if (windows != null && !windows.equals("UNSUPPORTED")) {
                subLines.add("Windows " + windows);
            }
            subLines.add("Lights " + _textOr(values.get("lights")));
            subLines.add("Bonnet " + _textOr(values.get("bonnet")));
            subLines.add("Trunk " + _textOr(values.get("trunk")));
            var sunroof = values.get("sunroof") as String?;
            if (sunroof != null && !sunroof.equals("UNSUPPORTED")) {
                subLines.add("Sunroof " + sunroof);
            }
        } else if (key.equals("charging")) {
            value = _numberText(values.get("batterySocPercent"), "%");
            subLines.add(_textOr(values.get("state")));
            var rangeMeters = values.get("rangeMeters");
            if (rangeMeters != null && (rangeMeters instanceof Number)) {
                subLines.add(((rangeMeters as Number) / 1000).toString() + " km range");
            }
            var remainingMinutes = values.get("remainingMinutes");
            if (remainingMinutes != null) {
                subLines.add(_textOr(remainingMinutes) + " min to full");
            }
        } else if (key.equals("fuelStatus")) {
            value = _numberText(values.get("totalRangeInKm"), " km");
            var primary = values.get("primary") as Dictionary?;
            if (primary != null) {
                subLines.add(_textOr(primary.get("engineType")) + " " + _numberText(primary.get("percent"), "%"));
            }
            var secondary = values.get("secondary") as Dictionary?;
            if (secondary != null) {
                subLines.add(_textOr(secondary.get("engineType")) + " " + _numberText(secondary.get("percent"), "%"));
            }
        } else if (key.equals("odometer")) {
            value = _numberText(values.get("mileageKm"), " km");
        } else { // "airConditioning": the field test's central example
            value = _textOr(values.get("state"));
            // US-019: front/rear shown separately, UNSUPPORTED omitted (the
            // same convention already applied to windows/sunroof above);
            // absent means "never reported", which STAYS absent here rather
            // than being displayed as anything.
            var heatFront = values.get("windowHeatingFront") as String?;
            if (heatFront != null && !heatFront.equals("UNSUPPORTED")) {
                subLines.add("Front window heat " + heatFront);
            }
            var heatRear = values.get("windowHeatingRear") as String?;
            if (heatRear != null && !heatRear.equals("UNSUPPORTED")) {
                subLines.add("Rear window heat " + heatRear);
            }
        }

        // US-010: "given anything is open or unlocked, then that is visible
        // without colour alone carrying the meaning": the LOCKED/UNLOCKED/
        // OPEN wording itself already carries it; colour is reinforcement,
        // never the only signal.
        var valueColor = MonochromeTest.color(emphasize ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE);
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 100, Graphics.FONT_NUMBER_MEDIUM, value, Graphics.TEXT_JUSTIFY_CENTER);

        // US-059: the same icon-per-state used on ControlsView's top strip,
        // the glance and the complications, see StateIcons.mc. Not every
        // page has one (fuelStatus/odometer aren't part of the seven-state
        // vocabulary US-059 names), in which case _iconFor() returns null
        // and nothing is drawn. Positioned from the value text's OWN
        // measured width (dc.getTextWidthInPixels()), never a guessed fixed
        // offset: "LOCKED" and "TRUNK OPEN" are very different widths, and
        // US-058 requires the value to stay the largest element, never
        // partly hidden behind this icon. Clamped so a pathologically wide
        // value can never push the icon past the round bezel's own safe
        // margin.
        var icon = _iconFor(key, values);
        if (icon != null) {
            var valueWidth = dc.getTextWidthInPixels(value, Graphics.FONT_NUMBER_MEDIUM);
            var valueHeight = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
            var iconX = centerX + (valueWidth / 2) + 20;
            var maxX = dc.getWidth() - 18;
            if (iconX > maxX) {
                iconX = maxX;
            }
            StateIcons.draw(dc, icon as Symbol, iconX, 100 + (valueHeight / 2), 12, valueColor);
        }

        dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
        var lineY = 152;
        // At most 3 sub-lines fit between the value and the age line on a
        // 260px-tall round face without crowding either.
        var lineCount = subLines.size();
        if (lineCount > 3) {
            lineCount = 3;
        }
        for (var i = 0; i < lineCount; i += 1) {
            dc.drawText(centerX, lineY, Graphics.FONT_XTINY, subLines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
            lineY += 16;
        }

        _drawAge(dc, centerX, section.age);
    }

    function _kindLabel(kind as String) as String {
        if (kind.equals(VehicleState.KIND_UNAVAILABLE)) {
            return "Temporarily unavailable";
        }
        if (kind.equals(VehicleState.KIND_DISABLED)) {
            return "Switched off for this car";
        }
        if (kind.equals(VehicleState.KIND_UNKNOWN)) {
            return "No data yet - refresh to fetch";
        }
        return "Not supported by this car";
    }

    function _kindColor(kind as String) as Graphics.ColorType {
        if (kind.equals(VehicleState.KIND_DISABLED)) {
            return Graphics.COLOR_LT_GRAY;
        }
        return Graphics.COLOR_YELLOW;
    }

    // US-010: distinct, plain-language states. Never left as the raw enum
    // for the four documented values, but still passed through verbatim for
    // anything this screen has never seen (openapi.json: "clients must
    // tolerate values they do not recognize", see
    // VehicleStateTests.unrecognisedEnumValuesPassThrough).
    function _lockLabel(raw as String?) as String {
        if (raw == null) {
            return EM_DASH;
        }
        if (raw.equals("YES")) {
            return "LOCKED";
        }
        if (raw.equals("NO")) {
            return "UNLOCKED";
        }
        if (raw.equals("OPENED")) {
            return "OPEN";
        }
        if (raw.equals("TRUNK_OPENED")) {
            return "TRUNK OPEN";
        }
        if (raw.equals("UNKNOWN")) {
            return "UNKNOWN";
        }
        return raw;
    }

    function _isInsecure(raw as String?) as Boolean {
        return raw != null && !raw.equals("YES");
    }

    // US-059: which of StateIcons' seven states (if any) applies to the
    // page currently on screen: null for fuelStatus/odometer, which carry
    // no lock/charging/climate state of their own.
    function _iconFor(key as String, values as Dictionary) as Symbol? {
        if (key.equals("status")) {
            return StateIcons.forLockStatus(values.get("doorsLocked") as String?);
        }
        if (key.equals("charging")) {
            return StateIcons.forChargingStatus(values.get("state") as String?);
        }
        if (key.equals("airConditioning")) {
            return StateIcons.forClimateStatus(values.get("state") as String?);
        }
        return null;
    }

    function _titleFor(key as String) as String {
        if (key.equals("status")) {
            return "LOCK & DOORS";
        }
        if (key.equals("charging")) {
            return "CHARGING";
        }
        if (key.equals("fuelStatus")) {
            return "FUEL / RANGE";
        }
        if (key.equals("odometer")) {
            return "ODOMETER";
        }
        return "AIR CONDITIONING";
    }

    // US-008: "any value missing from the response, then its place shows an
    // em dash rather than a zero or a stale value": the only place a null
    // becomes visible text.
    function _textOr(value as Object?) as String {
        if (value == null) {
            return EM_DASH;
        }
        return value.toString();
    }

    function _numberText(value as Object?, suffix as String) as String {
        if (value == null) {
            return EM_DASH;
        }
        if (value instanceof Float) {
            return (value as Float).toNumber().toString() + suffix;
        }
        return value.toString() + suffix;
    }

    // US-009: this is the field test's central finding, made visible. Each
    // section's age comes from ITS OWN section.age, never a screen-wide
    // clock, so airConditioning at 17h and everything else at 12-13min
    // render as genuinely different lines (see mock's
    // stale-airconditioning-17h scenario and this task's manual
    // verification).
    function _drawAge(dc as Dc, centerX as Number, age as Number?) as Void {
        if (age == null) {
            dc.setColor(MonochromeTest.color(Graphics.COLOR_DK_GRAY), Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 210, Graphics.FONT_XTINY, "No data", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var ageSeconds = Time.now().value() - age;
        if (ageSeconds < 0) {
            ageSeconds = 0; // a clock skew must never render as a negative age
        }
        var stale = ageSeconds > 3600; // US-009: older than an hour is emphasised

        dc.setColor(MonochromeTest.color(stale ? Graphics.COLOR_RED : Graphics.COLOR_DK_GRAY), Graphics.COLOR_TRANSPARENT);
        var font = stale ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
        var text = (stale ? "! " : "") + _ageText(ageSeconds);
        dc.drawText(centerX, 210, font, text, Graphics.TEXT_JUSTIFY_CENTER);
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
        if (hours < 24) {
            var remainderMinutes = minutes - (hours * 60);
            return hours.toString() + "h " + remainderMinutes.toString() + "m ago";
        }
        var days = hours / 24;
        return days.toString() + "d ago";
    }

    function _drawBottomBar(dc as Dc, centerX as Number, height as Number) as Void {
        dc.setColor(MonochromeTest.color(Graphics.COLOR_DK_GRAY), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height - 22, Graphics.FONT_XTINY, "UP/DOWN pages - SELECT refresh", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _shorten(text as String) as String {
        if (text.length() > 42) {
            return text.substring(0, 42) as String;
        }
        return text;
    }

    private const EM_DASH as String = "—";

}

// BehaviorDelegate, never InputDelegate (docs/best-practices, "Interaction
// and interface"), and never overrides onBack(), so the device's own back
// behaviour (pop this view) stays exactly what it is everywhere else.
class StatusDelegate extends WatchUi.BehaviorDelegate {

    // A delegate is owned BY its view (pushed alongside it); holding a
    // strong reference back would be the A->B->A cycle
    // docs/best-practices/garmin-connect-iq.md warns about under "Break
    // reference cycles with weak()".
    private var _view as WeakReference;

    function initialize(view as StatusView) {
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

    function _resolve() as StatusView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as StatusView?;
    }

}
