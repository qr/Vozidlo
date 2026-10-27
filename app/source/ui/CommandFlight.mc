import Toybox.Lang;
import Toybox.System;

// One command in flight at a time, for every screen that sends one: home
// (CommandRunner), the charge limit and the charge mode. Up to 1.3 each kept
// its own `_sending`, and the limit and mode menus build a new delegate on
// every open, so a menu reopened while its command was on its way could
// confirm and send a second. The guards still answer per screen: home stays
// silent on :busy (Commands.guard), the charging menus go through Refusal.
//
// Set only when a request actually goes out, in each sender's send method,
// which ConfirmationPolicy calls once the user said yes (or straight away
// with "Confirm commands" off): Cancel or BACK on the confirmation never
// gets here. Cleared first thing in every response callback, whatever the
// code: 2xx, iOS -400 (Commands.isSent()) or any failure.
module CommandFlight {

    // A backstop, not the rule: Connect IQ answers every request, a lost
    // phone link and a time-out included, as a negative code. Should a
    // callback never come, commands would stay blocked until the app
    // restarted; after this long the flag stops blocking. Not measured,
    // chosen well past any request seen.
    const STALE_MS = 120000;

    var _startedAt as Number? = null;

    function start() as Void {
        _startedAt = System.getTimer();
    }

    function done() as Void {
        _startedAt = null;
    }

    function busy() as Boolean {
        var t = _startedAt;
        return t != null && blocks(System.getTimer() - t);
    }

    // Whether a command started elapsedMs ago still blocks the next. The
    // difference of two System.getTimer() values stays right across the
    // timer's wrap; it is only negative after more than about 24.8 days,
    // long past STALE_MS, so it no longer blocks.
    function blocks(elapsedMs as Number) as Boolean {
        return elapsedMs >= 0 && elapsedMs < STALE_MS;
    }

}
