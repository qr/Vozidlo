import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

// US-024: PUT /vehicles/{vin}/charging/limit. UP/DOWN steps through exactly
// ChargingLogic.limitChoices() (50-100 in tens, never the schema's full
// 1-100): modelled on TargetTemperatureSettingsView.mc's own UP/DOWN
// pattern rather than WatchUi.Picker, for the same reason that file already
// chose it: a single adjustable value needs nothing heavier, and this app
// has no other Picker usage to stay consistent with.
class ChargingLimitView extends WatchUi.View {

    private var _index as Number;
    private var _careTarget as Number?;
    private var _label as WatchUi.Text?;

    private var _statusMessage as String? = null;
    private var _statusIsError as Boolean = false;
    private var _sending as Boolean = false;

    // `current` is settings.targetStateOfChargeInPercent as last seen by
    // ChargingDetailView (cached or freshly fetched); `careTarget` is
    // batteryCareModeTargetValueInPercent, or null when the car has never
    // reported one: both are read-only inputs, this view never re-fetches
    // them itself.
    function initialize(current as Number?, careTarget as Number?) {
        View.initialize();
        _index = ChargingLogic.limitIndexFor(current);
        _careTarget = careTarget;
    }

    function onLayout(dc as Dc) as Void {
        var label = new WatchUi.Text({
            :text => _valueText(),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => 110,
            :justification => Graphics.TEXT_JUSTIFY_CENTER
        });
        _label = label;
        setLayout([ label ] as Array<WatchUi.Drawable>);
    }

    function onUpdate(dc as Dc) as Void {
        View.onUpdate(dc);
        var centerX = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 50, Graphics.FONT_SMALL, "Charge limit", Graphics.TEXT_JUSTIFY_CENTER);

        if (ChargingLogic.isRecommended(_currentValue(), _careTarget)) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 150, Graphics.FONT_XTINY, "Recommended (battery care)", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var message = _statusMessage;
        if (message != null) {
            dc.setColor(_statusIsError ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 176, Graphics.FONT_XTINY, message as String, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        TextBlock.drawFittedLine(dc, "UP/DOWN adjust - SELECT set", Graphics.FONT_XTINY,
            Graphics.COLOR_DK_GRAY, dc.getHeight() - 24);
    }

    function increase() as Void {
        var choices = ChargingLogic.limitChoices();
        if (_index < choices.size() - 1) {
            _index += 1;
        }
        _afterChange();
    }

    function decrease() as Void {
        if (_index > 0) {
            _index -= 1;
        }
        _afterChange();
    }

    function _afterChange() as Void {
        var label = _label;
        if (label != null) {
            label.setText(_valueText());
        }
        _statusMessage = null;
        WatchUi.requestUpdate();
    }

    function _currentValue() as Number {
        return ChargingLogic.limitChoices()[_index] as Number;
    }

    function _valueText() as String {
        return _currentValue().toString() + "%";
    }

    // ------------------------------------------------------------ sending

    // Same disabled-preconditions as ControlsView.activate() (US-040/
    // US-045): silently do nothing when there is nothing sensible to send,
    // except quota: that gets a visible reason, matching ControlsView's own
    // convention for the one precondition worth explaining on the spot.
    function send() as Void {
        if (_sending) {
            return;
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            return;
        }
        if (!Quota.canSpend()) {
            _statusMessage = "Quota spent for this hour";
            _statusIsError = true;
            WatchUi.requestUpdate();
            return;
        }
        var settings = getApp().getSettings();
        if (!settings.vinValid || settings.apiKey.length() == 0) {
            return;
        }
        // US-024 carries no explicit "always confirm" entry in
        // ConfirmationPolicy's table: it is reversible and low-stakes like
        // the climate/charging start commands, so ConfirmationPolicy.run()
        // sends it immediately unless the quota is nearly spent, exactly the
        // same rule every other command in this app follows. Never a second,
        // hand-rolled confirmation here.
        ConfirmationPolicy.run(ConfirmationPolicy.SET_CHARGE_LIMIT, "Set limit to " + _valueText() + "?",
            method(:_sendLimit), method(:_announceSent));
    }

    function _sendLimit() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        var body = { "targetStateOfChargeInPercent" => _currentValue() } as Dictionary<Object, Object>;
        ApiClient.setChargingLimit(settings.vin, body, settings.apiKey, method(:_onCommandResponse));
    }

    // US-024/the task's KEY CONSTRAINT: this command omits :responseType, so
    // any error (a real 422 included) comes back as a negative transport
    // code with the problem+json body unreadable (see ApiClient.mc). That
    // still means the car refused this limit; it never means "we don't know
    // what happened", so this is worded as a refusal, not a generic failure,
    // and never claims to know the specific reason.
    function _onCommandResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _sending = false;

        if (responseCode >= 200 && responseCode < 300) {
            Quota.recordHeaders(null, null, null);
            WatchUi.requestUpdate();
            return;
        }

        var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (body != null) ? (body.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        _statusMessage = "Vehicle refused: " + _shorten(ProblemDetail.describe(responseCode, body, Quota.retryAfterUntil()).text);
        _statusIsError = true;
        WatchUi.requestUpdate();
    }

    function _announceSent() as Void {
        _statusMessage = "Command sent";
        _statusIsError = false;
        WatchUi.requestUpdate();
    }

    function _shorten(text as String) as String {
        if (text.length() > 30) {
            return text.substring(0, 30) as String;
        }
        return text;
    }

}

// BehaviorDelegate, back untouched. UP/DOWN adjust; SELECT sends: mirrors
// TargetTemperatureSettingsDelegate's own onPreviousPage/onNextPage mapping.
class ChargingLimitDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WeakReference;

    function initialize(view as ChargingLimitView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onPreviousPage() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.increase();
        }
        return true;
    }

    function onNextPage() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.decrease();
        }
        return true;
    }

    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.send();
        }
        return true;
    }

    function _resolve() as ChargingLimitView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ChargingLimitView?;
    }

}
