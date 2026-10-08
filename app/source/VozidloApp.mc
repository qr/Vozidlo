import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point and lifecycle owner. Kept deliberately thin: state restore/persist and
// settings reload live here; everything else is delegated to Settings and the views.
//
// Note on (:glance) and (:typecheck(disableGlanceCheck)), the hard way.
//
// Adding getGlanceView() makes this class reachable from glance mode, and
// the compiler then builds a SECOND, separate binary for that scope
// containing only code annotated (:glance). This is a linking rule, not a
// budget warning: a symbol without the annotation is not merely discouraged
// in glance scope, it is ABSENT from that binary, and calling it throws
// "Illegal Access (Out of Bounds): Failed invoking <symbol>" at runtime.
//
// (:typecheck(disableGlanceCheck)) silences the compiler's warning about
// such a call. It does not add the symbol. An earlier version of this file
// used it on onStart() with the reasoning that Settings.load() "only does
// cheap Properties reads, nothing that could overflow the glance budget":
// true, and beside the point. The app crashed on every launch of the glance
// until Settings.mc, model/Cache.mc and ui/StateIcons.mc were annotated
// (:glance) for real. Annotating a module is enough; its members follow.
//
// So the suppression is legitimate in exactly one case: a method that is
// never INVOKED in glance scope. The SDK's Glances doc names onStart() and
// getGlanceView() as the two that run there, so getInitialView() and
// getSettingsView() below qualify and keep the annotation. onStart(),
// onSettingsChanged() and getSettings() do not, and reach only
// (:glance)-annotated code now.
class VozidloApp extends Application.AppBase {

    private var _settings as Settings.Config?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() restores state. There is no runtime state to restore yet beyond the
    // parsed settings, which are loaded unconditionally so getInitialView() and every
    // view always have a usable Config.
    function onStart(state as Dictionary?) as Void {
        _settings = Settings.load();
    }

    // The system calls onStop() both on a real quit and when it is reclaiming memory
    // (state.get(:suspend) == true) rather than quitting outright. Persist only in the
    // latter case; in the former there is nothing worth keeping beyond what Settings /
    // Properties already hold. Task 4 adds cached vehicle state and quota counters to
    // Application.Storage here.
    function onStop(state as Dictionary?) as Void {
        if (state != null && (state.get(:suspend) as Boolean?) == true) {
            // Nothing to persist yet.
        }
    }

    // A phone-side settings edit must take effect without an app restart (US-001).
    function onSettingsChanged() as Void {
        _settings = Settings.load();
        WatchUi.requestUpdate();
    }

    // Exposes the parsed settings to views without them touching Properties directly.
    function getSettings() as Settings.Config {
        var settings = _settings;
        if (settings == null) {
            settings = Settings.load();
            _settings = settings;
        }
        return settings;
    }

    // Task 5 (onboarding) hook: single, additive branch: missing/invalid
    // config, a key that has never had a successful request, or a key old
    // enough to warrant the 159-day expiry estimate all route through the
    // onboarding gate first; everything else falls through unchanged. See
    // ui/OnboardingGate.mc for the full decision. Once configuration is
    // valid, home (the Night Panel hero list, ui/HomeMenu.mc) IS the app
    // (US-036: "land on the controls, not on a status page"); it is opened
    // only through HomeScreen so this file never names its classes.
    (:typecheck(disableGlanceCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var gate = Onboarding.gateView(getSettings());
        if (gate != null) {
            return [ gate, new OnboardingDelegate(gate) ];
        }
        return HomeScreen.view();
    }

    // US-018: the only on-device settings screen this app has, see
    // ui/TargetTemperatureSettingsView.mc. A watch app may offer one
    // (docs/best-practices); watch faces and data fields may not.
    (:typecheck(disableGlanceCheck))
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var view = new TargetTemperatureSettingsView();
        return [ view, new TargetTemperatureSettingsDelegate(view) ];
    }

    // Task 10 (US-034/US-035): the glance carousel entry point. VozidloGlanceView
    // reads only from Cache.mc: never makes a request, in any code path
    // (see ui/GlanceView.mc's own header for the full argument and how it
    // was verified). Selecting the glance in the carousel falls through to
    // the SAME getInitialView() above, which already lands on home with
    // the primary action focused (US-037): nothing extra to wire here, only
    // not to break it.
    (:glance)
    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [ new VozidloGlanceView() ];
    }

}

function getApp() as VozidloApp {
    return Application.getApp() as VozidloApp;
}
