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

    // Whole degrees, in whatever unit Settings.Config.temperatureUnit names:
    // never converted here (the air-conditioning command, lifted from
    // ControlsView into Commands.mc, explains why the app does no C/F
    // conversion).
    private var _value as Number;
    private var _unitSuffix as String;

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
    }

    // Monochrome flag cached per onShow (A21).
    function onShow() as Void {
        Theme.refresh();
    }

    // PoC NSet.temp: the title sits at y 48 because "Target temperature" is
    // about 182 px in FONT_TINY and the chord at y 34 leaves only 158; the
    // value is centred, digits in the number font and the unit in a text
    // font (A8: FONT_NUMBER_MEDIUM has no "C" or "F"); "+" and "−" glyphs at
    // UP and DOWN replace the old "UP/DOWN to adjust" line (A3 superseded).
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        Ui.title(dc, TITLE, TITLE_Y);
        var numFont = Graphics.FONT_NUMBER_MEDIUM;
        var y = dc.getHeight() / 2 - dc.getFontHeight(numFont) / 2;
        Ui.drawValueWithUnit(dc, dc.getWidth() / 2, y, _value.toString(), _unitSuffix,
            numFont, Graphics.FONT_MEDIUM, Theme.TEXT_1);
        Bezel.glyph(dc, Bezel.BTN_UP, :plus, Theme.TEXT_1, null);
        Bezel.glyph(dc, Bezel.BTN_DOWN, :minus, Theme.TEXT_1, null);
    }

    private const TITLE as String = "Target temperature";
    private const TITLE_Y = 48;

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
        // directly so the home screen's next command picks this up immediately.
        getApp().onSettingsChanged();
        WatchUi.requestUpdate();
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

    // Touch: a swipe up raises the value, like pushing a slider up (A19).
    // BehaviorDelegate maps swipe up to onNextPage(), which is DOWN's
    // "decrease", so swipes are handled here and never reach the page
    // behaviours; the buttons keep UP = +1, DOWN = -1.
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            return onPreviousPage();
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            return onNextPage();
        }
        return false;
    }

    function _resolve() as TargetTemperatureSettingsView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as TargetTemperatureSettingsView?;
    }

}
