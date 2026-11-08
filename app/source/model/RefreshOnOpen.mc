import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// The optional refresh when the app opens (setting "Refresh on open", off by
// default): one status read, at most once per chosen period, never in the
// background and never from the glance. The exception to "Never poll" in
// docs/decisions.md.
//
// The period runs from our own last status refresh attempt, by hand or on
// open (StatusModel.refresh records it too), not from the car's
// carCapturedTimestamp: a parked car keeps an old timestamp, so a car-based
// age would fire on every open and change nothing. The attempt is recorded
// before the request goes out, whatever its outcome, so the automatic cost
// stays at one request per period also when requests fail (a 5xx counts
// against the quota too).
//
// With the setting on, every open and every landed refresh writes one line
// with System.println, which on a watch appends to
// GARMIN/APPS/LOGS/<PRG name>.TXT when that file
// exists (create it empty over USB; INSTALL.md "When something goes wrong"),
// and goes to the console in the simulator. Times and ages only, nothing
// that identifies the user or the car:
//   11-08 10:40:12 RO open 2h last 185m: started st 1020m ch 1020m
//       period, minutes since our last attempt ("-" for none), the decision
//       (notDue, offline, quota, unconfigured, started), and the
//       age in minutes of the car's status and charging data before it
//   11-08 10:40:15 RO done 200 st 12m ch 3m
//       the response code (0 when none was seen), and the same ages after it
module RefreshOnOpen {

    const STORAGE_KEY = "refreshOnOpen";
    const HOUR_SECONDS = 3600;

    // Seconds since the epoch to use instead of the real clock; null in the
    // app. Tests set it, as Quota.nowOverride.
    var nowOverride as Number? = null;

    // The model whose request is out after a started run(), so a refresh
    // on Status (another StatusModel) can see it and wait (busy()).
    var _running as StatusModel? = null;

    function _now() as Number {
        return nowOverride != null ? nowOverride as Number : Time.now().value();
    }

    // ------------------------------------------------------------ pure

    // Due when the setting is on and the last attempt is at least `hours`
    // old, or there was none. An attempt in the future (the clock was set
    // back) is not due: it waits until the clock passes it again rather than
    // firing on every open.
    function isDue(hours as Number, lastAttempt as Number?, now as Number) as Boolean {
        if (hours <= 0) {
            return false;
        }
        if (lastAttempt == null) {
            return true;
        }
        if (lastAttempt > now) {
            return false;
        }
        return now - lastAttempt >= hours * HOUR_SECONDS;
    }

    // ------------------------------------------------------------ state

    function lastAttempt() as Number? {
        return Storage.getValue(STORAGE_KEY) as Number?;
    }

    function record() as Void {
        Storage.setValue(STORAGE_KEY, _now());
    }

    function clear() as Void {
        Storage.deleteValue(STORAGE_KEY);
    }

    // ------------------------------------------------------------ run

    // Sends the status read through `model` when due and nothing refuses it.
    // Returns :off, :notDue, a Refusal reason (:busy, :offline, :quota,
    // :unconfigured; nothing recorded, so the next open tries again) or what
    // model.refresh() returned (:started). `refusal` is passed in so the
    // tests need no phone; the app passes Refusal.current().
    function run(model as StatusModel, hours as Number, refusal as Symbol) as Symbol {
        if (hours <= 0) {
            return :off;
        }
        var now = _now();
        var last = lastAttempt();
        var result = refusal;
        if (!isDue(hours, last, now)) {
            result = :notDue;
        } else if (refusal == :ok) {
            record();
            result = model.refresh();
            if (result == :started) {
                _running = model;
            }
        }
        _log("open " + hours.toString() + "h last " + _minutes(last, now) + ": " + word(result)
            + _carAges(now));
        return result;
    }

    // A refresh on open is out: any other status refresh counts as busy.
    function busy() as Boolean {
        var model = _running;
        if (model != null && model.isFetching()) {
            return true;
        }
        _running = null;
        return false;
    }

    // The refresh on open came back (HomeMenu notices it at the next draw).
    function logDone(code as Number) as Void {
        _log("done " + code.toString() + _carAges(_now()));
    }

    // ------------------------------------------------------------ log

    // The decision as a log word: Symbol.toString() gives no name.
    function word(result as Symbol) as String {
        var words = {
            :off => "off", :notDue => "notDue", :busy => "busy", :offline => "offline",
            :quota => "quota", :unconfigured => "unconfigured", :started => "started"
        } as Dictionary<Symbol, String>;
        var w = words.get(result);
        return w != null ? w : "other";
    }

    // " st <m>m ch <m>m": age of the car's own status and charging data.
    function _carAges(now as Number) as String {
        return " st " + _minutes(Cache.sectionAge("status"), now) + " ch "
            + _minutes(Cache.sectionAge("charging"), now);
    }

    // Whole minutes from `at` to `now` with an "m", or "-" when unknown.
    function _minutes(at as Number?, now as Number) as String {
        if (at == null) {
            return "-";
        }
        return ((now - at) / 60).toString() + "m";
    }

    function _log(text as String) as Void {
        var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        System.println(_two(i.month as Number) + "-" + _two(i.day as Number) + " " + _two(i.hour as Number)
            + ":" + _two(i.min as Number) + ":" + _two(i.sec as Number) + " RO " + text);
    }

    function _two(n as Number) as String {
        return n < 10 ? "0" + n.toString() : n.toString();
    }

}
