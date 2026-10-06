import Toybox.Attention;
import Toybox.Lang;
import Toybox.WatchUi;

// US-062, implemented exactly once so every command-sending screen: this
// task's ControlsView, and whatever task 8 adds for charging: inherits the
// same rule rather than each hand-rolling its own confirm/skip branch.
//
// The policy is a fixed table plus one override: a handful of actions
// interrupt something already running or cost something scarce (a fuel
// burn, stored data) and always confirm; everything else is reversible and
// goes out on a single press. But near the quota limit, a wasted press is
// no longer free, so Quota.isLow() (US-040's own "fewer than three left"
// threshold: reused, not duplicated) promotes every action to "ask first",
// reversible or not.
module ConfirmationPolicy {

    // One Symbol per command this policy (and, later, task 8's charging
    // screen) knows about. Central here rather than re-declared per screen,
    // so a typo can't silently create a second, unrecognised action name.
    const START_CLIMATE as Symbol = :startClimate;
    const STOP_CLIMATE as Symbol = :stopClimate;
    const START_VENTILATION as Symbol = :startVentilation;
    const STOP_VENTILATION as Symbol = :stopVentilation;
    const START_AUX_HEATING as Symbol = :startAuxHeating;
    const STOP_AUX_HEATING as Symbol = :stopAuxHeating;
    const START_CHARGING as Symbol = :startCharging;
    const STOP_CHARGING as Symbol = :stopCharging;
    const SET_CHARGE_LIMIT as Symbol = :setChargeLimit;
    const SET_CHARGE_MODE as Symbol = :setChargeMode;
    const CLEAR_DATA as Symbol = :clearData;

    // A command that performs the actual network call, invoked with no
    // arguments: every ApiClient.xxx() call site already has vin/apiKey in
    // scope, so the Method it hands here needs none.
    typedef SendCommand as Method() as Void;
    // Called once, right after `send` has actually been invoked (on either
    // branch below), so the caller can update its own screen: set the
    // "Command sent" text, request a redraw. Kept separate from `send`
    // itself so this module never needs to know what a screen looks like.
    typedef Announce as Method() as Void;

    // US-062's table, verbatim: these interrupt something already running
    // (stopping a charge session, erasing data) or burn fuel (the auxiliary
    // heater): everything else is reversible and low-stakes.
    function _alwaysConfirms(action as Symbol) as Boolean {
        if (action == STOP_CHARGING) {
            return true;
        }
        if (action == START_AUX_HEATING || action == STOP_AUX_HEATING) {
            return true;
        }
        return action == CLEAR_DATA;
    }

    // US-040 + US-062: "when the quota is nearly spent, even reversible
    // actions ask, because the press now costs something beyond itself."
    // Quota.isLow() is exactly that threshold, already tested in
    // QuotaTests.mc: reused here rather than re-implemented.
    function requiresConfirmation(action as Symbol) as Boolean {
        if (_alwaysConfirms(action)) {
            return true;
        }
        return Quota.isLow();
    }

    // The single entry point every screen calls instead of writing its own
    // "should this show a dialog" branch. `confirmMessage` is only ever
    // shown when the policy says to ask: docs/best-practices: "phrase it
    // as an explicit yes/no question."
    //
    // US-062's other rule: "every command vibrates once and shows 'Command
    // sent' immediately": is enforced here too, on whichever branch
    // actually fires: the vibration is common to both paths (send()
    // followed immediately by a single buzz), so a future caller cannot
    // forget it by only handling one branch.
    function run(action as Symbol, confirmMessage as String, send as SendCommand, announce as Announce) as Void {
        if (requiresConfirmation(action)) {
            var dialog = new WatchUi.Confirmation(confirmMessage);
            WatchUi.pushView(dialog, new ConfirmSendDelegate(send, announce), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        sendAndAnnounce(send, announce);
    }

    // Not underscore-prefixed, unlike this module's other helpers: it is
    // deliberately called from ConfirmSendDelegate below (a different
    // class, same file) once a confirmation comes back "yes", so it needs
    // to be reachable from outside this module's own functions.
    function sendAndAnnounce(send as SendCommand, announce as Announce) as Void {
        send.invoke();
        _vibrateOnce();
        announce.invoke();
    }

    // Best-effort: `has` per docs/best-practices ("probe optional API
    // surface with has") since not every device honours a vibrate request,
    // and a missing buzz must never block the command itself from going
    // out: the visible "Command sent" text is the feedback that matters.
    function _vibrateOnce() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([ new Attention.VibeProfile(50, 200) ] as Array<Attention.VibeProfile>);
        }
    }

}

// Only ever constructed by ConfirmationPolicy.run() above: never holds a
// back-reference to a view, so there is no A->B->A cycle to break with
// weak() here (docs/best-practices).
class ConfirmSendDelegate extends WatchUi.ConfirmationDelegate {

    private var _send as ConfirmationPolicy.SendCommand;
    private var _announce as ConfirmationPolicy.Announce;

    function initialize(send as ConfirmationPolicy.SendCommand, announce as ConfirmationPolicy.Announce) {
        ConfirmationDelegate.initialize();
        _send = send;
        _announce = announce;
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            ConfirmationPolicy.sendAndAnnounce(_send, _announce);
        }
        return true;
    }

}
