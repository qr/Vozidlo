import Toybox.Attention;
import Toybox.Lang;

// US-062, implemented exactly once so every command-sending screen: home's
// rows (Commands.mc), the charging mode and limit menus: inherits the
// same rule rather than each hand-rolling its own confirm/skip branch.
//
// The rule is one setting: with "Confirm commands" on (the default), every
// command asks first, on a screen of the app's own (ui/CommandConfirm.mc);
// with it off, nothing asks. Up to 1.3 a fixed table (stop charging, the
// auxiliary heater) and a low quota decided, and everything else went out on
// one tap, so a user who kept tapping a row sent the command again with every
// tap (decisions.md "Every command is confirmed, unless the user switches it
// off.").
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

    // A command that performs the actual network call, invoked with no
    // arguments: every ApiClient.xxx() call site already has vin/apiKey in
    // scope, so the Method it hands here needs none.
    typedef SendCommand as Method() as Void;
    // Called once, right after `send` has actually been invoked (on either
    // branch below), so the caller can update its own screen: set the
    // "Command sent" text, request a redraw. Kept separate from `send`
    // itself so this module never needs to know what a screen looks like.
    typedef Announce as Method() as Void;

    // US-062: every command asks while the setting is on, and none does
    // while it is off: no command is exempt either way, not stop charging,
    // not the auxiliary heater, not a low quota. Pure (the setting is passed
    // in) so the tests can cover both settings; the action stays in the
    // signature so a future exception for one command lands here, not in a
    // caller.
    function requiresConfirmation(action as Symbol, confirmCommands as Boolean) as Boolean {
        return confirmCommands;
    }

    // The single entry point every screen calls instead of writing its own
    // "should this ask" branch. `confirmMessage` is only ever shown when the
    // policy says to ask: docs/best-practices: "phrase it as an explicit
    // yes/no question."
    //
    // US-062's other rule: "every command vibrates once and shows 'Command
    // sent' immediately": is enforced here too, on whichever branch
    // actually fires: the vibration is common to both paths (send()
    // followed immediately by a single buzz), so a future caller cannot
    // forget it by only handling one branch.
    function run(action as Symbol, confirmMessage as String, send as SendCommand, announce as Announce) as Void {
        if (requiresConfirmation(action, getApp().getSettings().confirmCommands)) {
            CommandConfirm.open(action, confirmMessage, send, announce);
            return;
        }
        sendAndAnnounce(send, announce);
    }

    // Not underscore-prefixed, unlike this module's other helpers: it is
    // deliberately called from CommandConfirmDelegate (ui/CommandConfirm.mc)
    // once the action row is picked, so it needs to be reachable from
    // outside this module's own functions.
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
