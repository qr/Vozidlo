import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Why a refresh or a charging command was not sent, and the one wording for
// it (US-012, US-013, US-040, US-045). Status, Charging detail, Find my car
// and the charge mode and limit menus check the same four things in the same
// order (the old StatusView.refresh()); before this module only Status said
// why, the others returned silently or named the quota alone. The check and
// its words live here once, pure with the platform state passed in, so the
// tests need no phone. Home's commands keep Commands.guard(), whose silence
// for a missing phone is US-045's rule there: the hero line already says it.
module Refusal {

    // :busy, :offline, :quota or :unconfigured, or :ok when the request may
    // go. A missing phone comes first because it explains every other
    // refusal (US-013); setup last, guiding it is onboarding's job.
    function check(busy as Boolean, phoneConnected as Boolean, canSpend as Boolean,
                   configured as Boolean) as Symbol {
        if (busy) {
            return :busy;
        }
        if (!phoneConnected) {
            return :offline;
        }
        if (!canSpend) {
            return :quota;
        }
        if (!configured) {
            return :unconfigured;
        }
        return :ok;
    }

    // Toast text for a refusal; null for :ok and anything else that is not
    // one (StatusModel's :started), where the screen's own line says enough.
    function text(reason as Symbol, resetSeconds as Number?) as String? {
        if (reason == :busy) {
            return "Already refreshing";
        }
        if (reason == :offline) {
            return Commands.NO_PHONE;
        }
        if (reason == :quota) {
            return quotaSpentText(resetSeconds);
        }
        if (reason == :unconfigured) {
            return "Not set up yet";
        }
        return null;
    }

    // A command picked from a menu: as text(), except that :busy stays
    // silent, as on home (a stray second press while one is on its way).
    function commandText(reason as Symbol, resetSeconds as Number?) as String? {
        if (reason == :busy) {
            return null;
        }
        return text(reason, resetSeconds);
    }

    // US-012: worded as an estimate, because Connect IQ cannot read
    // RateLimit-Remaining (Quota.mc).
    function quotaSpentText(resetSeconds as Number?) as String {
        if (resetSeconds != null) {
            return "Quota spent, resets in ~" + (resetSeconds / 60).toString() + " min";
        }
        return Commands.QUOTA_SPENT;
    }

    // ------------------------------------------------------------ live

    // check() against the phone, the quota estimate and the settings now.
    function current(busy as Boolean) as Symbol {
        var settings = getApp().getSettings();
        var configured = settings.vinValid && settings.apiKey.length() > 0;
        return check(busy, System.getDeviceSettings().phoneConnected, Quota.canSpend(), configured);
    }

    // The menu that asked has closed by the time a refusal is known (A14),
    // so a toast on the screen underneath is the only place to say it.
    // Guarded with `has`, like every toast here (docs/best-practices "Probe
    // optional API surface with has").
    function toast(message as String?) as Void {
        if (message != null && (WatchUi has :showToast)) {
            WatchUi.showToast(message, null);
        }
    }

}
