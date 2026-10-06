import Toybox.Lang;
import Toybox.Test;

// Unit tests for api/ConfirmationPolicy.mc (US-062): which actions ask
// first, which do not, and the near-quota override that promotes even a
// reversible action to "ask first" once the estimated budget is nearly
// spent (US-040's own threshold, reused rather than re-implemented).
module ConfirmationPolicyTests {

    (:test)
    function reversibleActionsSendWithoutConfirmationByDefault(logger as Logger) as Boolean {
        Quota.clear();
        var reversible = [
            ConfirmationPolicy.START_CLIMATE,
            ConfirmationPolicy.STOP_CLIMATE,
            ConfirmationPolicy.START_VENTILATION,
            ConfirmationPolicy.STOP_VENTILATION,
            ConfirmationPolicy.START_CHARGING,
            ConfirmationPolicy.SET_CHARGE_LIMIT,
            ConfirmationPolicy.SET_CHARGE_MODE
        ] as Array<Symbol>;

        for (var i = 0; i < reversible.size(); i += 1) {
            var action = reversible[i] as Symbol;
            if (ConfirmationPolicy.requiresConfirmation(action)) {
                logger.error("action " + action.toString() + " must not require confirmation with a healthy quota");
                return false;
            }
        }
        return true;
    }

    // US-062's table: these three, plus clearing stored data, always ask.
    // regardless of quota, because they interrupt something already
    // running or cost something scarce.
    (:test)
    function costlyActionsAlwaysConfirmRegardlessOfQuota(logger as Logger) as Boolean {
        Quota.clear();
        var costly = [
            ConfirmationPolicy.STOP_CHARGING,
            ConfirmationPolicy.START_AUX_HEATING,
            ConfirmationPolicy.STOP_AUX_HEATING,
            ConfirmationPolicy.CLEAR_DATA
        ] as Array<Symbol>;

        for (var i = 0; i < costly.size(); i += 1) {
            var action = costly[i] as Symbol;
            if (!ConfirmationPolicy.requiresConfirmation(action)) {
                logger.error("action " + action.toString() + " must always require confirmation");
                return false;
            }
        }
        return true;
    }

    // US-040 + US-062: near the quota limit, "the press now costs something
    // beyond itself": even a normally-immediate action asks first. Mirrors
    // the mock's own quota-nearly-spent scenario (RateLimit-Remaining
    // forced to 1).
    (:test)
    function nearQuotaLimitForcesConfirmationOnReversibleActions(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 1, 3600);

        if (!ConfirmationPolicy.requiresConfirmation(ConfirmationPolicy.START_CLIMATE)) {
            logger.error("a reversible action must confirm when the quota is nearly spent");
            return false;
        }
        if (!ConfirmationPolicy.requiresConfirmation(ConfirmationPolicy.START_VENTILATION)) {
            logger.error("every reversible action is covered by the near-quota override, not just climate");
            return false;
        }

        Quota.clear();
        return true;
    }

    // The boundary this override is built on (US-040's own "fewer than
    // three" rule, via Quota.isLow()): three remaining is healthy, not low.
    (:test)
    function healthyQuotaDoesNotForceConfirmation(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 3, 3600);

        if (ConfirmationPolicy.requiresConfirmation(ConfirmationPolicy.START_CLIMATE)) {
            logger.error("3 remaining is the boundary, not low yet, so no override should apply");
            return false;
        }

        Quota.clear();
        return true;
    }

}
