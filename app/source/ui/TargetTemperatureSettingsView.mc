import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// US-018's on-watch half: "adjustable on the watch as well as in phone
// settings." AppBase.getSettingsView() is a watch app's own hook for this
// (docs/best-practices: "watch faces and data fields may not" offer one).
// wired from VozidloApp.getSettingsView(). Every nudge commits immediately to
// the SAME Properties key the phone-side setting (settings.xml) edits, so
// there is exactly one value regardless of which side changed it last.
class TargetTemperatureSettingsView extends WatchUi.View {

    // Whole degrees, in whatever unit Settings.Config.temperatureUnit names
    //: never converted here (see ControlsView._airConditioningBody()'s own
    // comment on why this app does not do C/F conversion).
    private var _value as Number;
    private var _unitSuffix as String;
    private var _label as WatchUi.Text?;

    function initialize() {
        View.initialize();
        var settings = getApp().getSettings();
        _unitSuffix = settings.temperatureUnit.equals("F") ? "°F" : "°C";
        _value = _initialValue(settings);
    }

    // US-018's default chain, on-watch: an existing override first, then
    // what the car itself last reported (rounded: this picker only deals
    // in whole degrees), then a neutral seasonal-ish default so the picker
    // never starts at the 0 sentinel itself.
    function _initialValue(settings as Settings.Config) as Number {
        var existing = settings.targetTemperature;
        if (existing != null) {
            return existing;
        }
        var cached = Cache.section("airConditioning");
        var cachedValue = (cached != null) ? cached.get("targetValue") : null;
        if (cachedValue != null && cachedValue instanceof Float) {
            return (cachedValue as Float).toNumber();
        }
        if (cachedValue != null && cachedValue instanceof Number) {
            return cachedValue as Number;
        }
        return _unitSuffix.equals("°F") ? 70 : 21;
    }

    function onLayout(dc as Dc) as Void {
        var label = new WatchUi.Text({
            :text => _text(),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER,
            :justification => Graphics.TEXT_JUSTIFY_CENTER
        });
        _label = label;
        setLayout([ label ]);
    }

    function onUpdate(dc as Dc) as Void {
        View.onUpdate(dc);
        TextBlock.drawFittedLine(dc, "UP/DOWN to adjust", Graphics.FONT_XTINY,
            Graphics.COLOR_DK_GRAY, dc.getHeight() - 30);
    }

    function increase() as Void {
        _value += 1;
        if (_value > 100) {
            _value = 100;
        }
        _commit();
    }

    function decrease() as Void {
        _value -= 1;
        if (_value < 1) {
            _value = 1;
        }
        _commit();
    }

    // Commits on every nudge rather than requiring a separate "save" step:
    // this is a preference, not a command, so there is nothing to confirm
    // and nothing gained by making the user press a second button.
    function _commit() as Void {
        Properties.setValue("TargetTemperature", _value);
        // A Properties write made from inside the app, not synced in from
        // the phone, does not trigger onSettingsChanged() on its own (same
        // situation OnboardingClearConfirmDelegate documents): call it
        // directly so ControlsView's next command picks this up immediately.
        getApp().onSettingsChanged();
        var label = _label;
        if (label != null) {
            label.setText(_text());
        }
        WatchUi.requestUpdate();
    }

    function _text() as String {
        return _value.toString() + _unitSuffix;
    }

}

// BehaviorDelegate, back untouched: leaving this screen needs no explicit
// save (see _commit() above, called on every nudge).
class TargetTemperatureSettingsDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WeakReference;

    function initialize(view as TargetTemperatureSettingsView) {
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

    function _resolve() as TargetTemperatureSettingsView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as TargetTemperatureSettingsView?;
    }

}
