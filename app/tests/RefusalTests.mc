import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/Refusal.mc: the refresh and charging-command guards in
// the old StatusView order, and the words the toast uses (US-012, US-013,
// US-040, US-045).
module RefusalTests {

    (:test)
    function checkKeepsTheOldOrder(logger as Logger) as Boolean {
        if (Refusal.check(true, false, false, false) != :busy) {
            logger.error("a request in flight must win over everything");
            return false;
        }
        if (Refusal.check(false, false, false, false) != :offline) {
            logger.error("a missing phone comes before the quota");
            return false;
        }
        if (Refusal.check(false, true, false, false) != :quota) {
            logger.error("a spent quota comes before setup");
            return false;
        }
        if (Refusal.check(false, true, true, false) != :unconfigured) {
            logger.error("no key or VIN must refuse");
            return false;
        }
        if (Refusal.check(false, true, true, true) != :ok) {
            logger.error("everything in place must send");
            return false;
        }
        return true;
    }

    (:test)
    function textUsesTheSharedWording(logger as Logger) as Boolean {
        var offline = Refusal.text(:offline, null);
        if (offline == null || !offline.equals(Commands.NO_PHONE)) {
            logger.error("a missing phone must read " + Commands.NO_PHONE);
            return false;
        }
        var quota = Refusal.text(:quota, null);
        if (quota == null || !quota.equals(Commands.QUOTA_SPENT)) {
            logger.error("a spent quota without a reset time must read " + Commands.QUOTA_SPENT);
            return false;
        }
        if (!Refusal.quotaSpentText(720).equals("Quota spent, resets in ~12 min")) {
            logger.error("a known reset must be given in minutes");
            return false;
        }
        if (Refusal.text(:ok, null) != null || Refusal.text(:started, null) != null) {
            logger.error(":ok and :started need no toast");
            return false;
        }
        if (Refusal.text(:busy, null) == null || Refusal.text(:unconfigured, null) == null) {
            logger.error("a refused Refresh always says why");
            return false;
        }
        return true;
    }

    // A charge mode or limit pick that cannot go says why, except a second
    // press while one is on its way, which stays silent as on home.
    (:test)
    function commandTextIsSilentOnlyWhenBusy(logger as Logger) as Boolean {
        if (Refusal.commandText(:busy, null) != null) {
            logger.error("busy must stay silent for a command");
            return false;
        }
        var offline = Refusal.commandText(:offline, null);
        if (offline == null || !offline.equals(Commands.NO_PHONE)) {
            logger.error("an offline pick must not be silent");
            return false;
        }
        if (Refusal.commandText(:unconfigured, null) == null || Refusal.commandText(:quota, 60) == null) {
            logger.error("setup and quota refusals must say why");
            return false;
        }
        return true;
    }

}
