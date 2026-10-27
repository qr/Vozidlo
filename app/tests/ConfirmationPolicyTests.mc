import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for api/ConfirmationPolicy.mc (US-062) and its screen,
// ui/CommandConfirm.mc. Since the "Confirm commands" setting
// the rule is the setting alone: on, every command asks; off, none does.
// Up to 1.3 a table (stop charging, the auxiliary heater, clearing data)
// always asked and a low quota made everything ask; the tests that pinned
// that rule now pin that neither matters any more.
module ConfirmationPolicyTests {

    function _commands() as Array<Symbol> {
        return [
            ConfirmationPolicy.START_CLIMATE,
            ConfirmationPolicy.STOP_CLIMATE,
            ConfirmationPolicy.START_VENTILATION,
            ConfirmationPolicy.STOP_VENTILATION,
            ConfirmationPolicy.START_AUX_HEATING,
            ConfirmationPolicy.STOP_AUX_HEATING,
            ConfirmationPolicy.START_CHARGING,
            ConfirmationPolicy.STOP_CHARGING,
            ConfirmationPolicy.SET_CHARGE_LIMIT,
            ConfirmationPolicy.SET_CHARGE_MODE
        ] as Array<Symbol>;
    }

    // Was reversibleActionsSendWithoutConfirmationByDefault: by default
    // (a property that is missing reads as on) all ten commands ask first,
    // the reversible ones included.
    (:test)
    function everyCommandConfirmsByDefault(logger as Logger) as Boolean {
        var on = Settings.resolveConfirmCommands(null);
        var commands = _commands();
        for (var i = 0; i < commands.size(); i += 1) {
            var action = commands[i] as Symbol;
            if (!ConfirmationPolicy.requiresConfirmation(action, on)) {
                logger.error("action " + action.toString() + " must confirm with the default setting");
                return false;
            }
        }
        return true;
    }

    // Was costlyActionsAlwaysConfirmRegardlessOfQuota: with the setting off
    // nothing asks, the old always-confirm commands included.
    (:test)
    function nothingConfirmsWhenSwitchedOff(logger as Logger) as Boolean {
        var commands = _commands();
        for (var i = 0; i < commands.size(); i += 1) {
            var action = commands[i] as Symbol;
            if (ConfirmationPolicy.requiresConfirmation(action, false)) {
                logger.error("action " + action.toString() + " must send on one tap with the setting off");
                return false;
            }
        }
        return true;
    }

    // Was nearQuotaLimitForcesConfirmationOnReversibleActions and
    // healthyQuotaDoesNotForceConfirmation: a nearly spent quota (the mock's
    // quota-nearly-spent scenario, RateLimit-Remaining 1) no longer changes
    // the answer either way.
    (:test)
    function lowQuotaNoLongerDecides(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 1, 3600);
        var ok = true;
        if (ConfirmationPolicy.requiresConfirmation(ConfirmationPolicy.START_CLIMATE, false)) {
            logger.error("a low quota must not make a command ask with the setting off");
            ok = false;
        }
        if (!ConfirmationPolicy.requiresConfirmation(ConfirmationPolicy.START_CLIMATE, true)) {
            logger.error("a low quota must not stop a command asking with the setting on");
            ok = false;
        }
        Quota.clear();
        return ok;
    }

    // Every command has its own action row; "Send" is only the fallback
    // for an action this screen does not know.
    (:test)
    function everyCommandHasAnActionLabel(logger as Logger) as Boolean {
        var commands = _commands();
        for (var i = 0; i < commands.size(); i += 1) {
            var action = commands[i] as Symbol;
            if (CommandConfirm.actionLabel(action).equals("Send")) {
                logger.error("action " + action.toString() + " has no action label");
                return false;
            }
        }
        if (!CommandConfirm.actionLabel(ConfirmationPolicy.STOP_CHARGING).equals("Stop charging")) {
            logger.error("the action row repeats the home row's words");
            return false;
        }
        return true;
    }

    // A double tap's second tap lands within the guard and is ignored; a
    // pick after it counts. A wrapped timer (negative) is not a double tap.
    (:test)
    function aPickRightAfterOpeningIsIgnored(logger as Logger) as Boolean {
        if (CommandConfirm.acceptsSend(0) || CommandConfirm.acceptsSend(CommandConfirm.PICK_GUARD_MS - 1)) {
            logger.error("a pick inside the guard must be ignored");
            return false;
        }
        if (!CommandConfirm.acceptsSend(CommandConfirm.PICK_GUARD_MS) || !CommandConfirm.acceptsSend(3000)) {
            logger.error("a pick after the guard must send");
            return false;
        }
        if (!CommandConfirm.acceptsSend(-5)) {
            logger.error("a wrapped timer must not block the send");
            return false;
        }
        return true;
    }

    // The owner's choice (2026-10-27): the action is row 0 and has the
    // focus, so the question above it stays in view; Cancel is row 1.
    (:test)
    function theActionIsFocusedAboveCancel(logger as Logger) as Boolean {
        var menu = new CommandConfirmMenu("Stop charging?", "Stop charging", true);
        var first = menu.itemAt(0);
        var second = menu.itemAt(1);
        if (first == null || second == null || first.getId() != CommandConfirm.SEND || second.getId() != CommandConfirm.CANCEL) {
            logger.error("row 0 must be the action and row 1 Cancel");
            return false;
        }
        if (!first.getText().equals("Stop charging")) {
            logger.error("the action row must carry the action label");
            return false;
        }
        if (menu.focusState().focus() != 0 || !menu.titleShown()) {
            logger.error("the action must have the focus on open, with the question in view");
            return false;
        }
        return true;
    }

    // The owner's choice (2026-10-27): the four stops get a red action pill;
    // the starts, the charge limit and the charge mode keep the accent.
    (:test)
    function onlyStopsAreRed(logger as Logger) as Boolean {
        var commands = _commands();
        for (var i = 0; i < commands.size(); i += 1) {
            var action = commands[i] as Symbol;
            var stop = action == ConfirmationPolicy.STOP_CLIMATE || action == ConfirmationPolicy.STOP_VENTILATION
                || action == ConfirmationPolicy.STOP_AUX_HEATING || action == ConfirmationPolicy.STOP_CHARGING;
            if (CommandConfirm.isStop(action) != stop) {
                logger.error("action " + action.toString() + (stop ? " is a stop" : " is not a stop"));
                return false;
            }
        }
        var red = new CommandConfirmMenu("Stop charging?", "Stop charging", true).itemAt(0);
        var accent = new CommandConfirmMenu("Set limit to 80%?", "Set limit", false).itemAt(0);
        if (red == null || red.pill() != Theme.DESTRUCTIVE || accent == null || accent.pill() != null) {
            logger.error("a stop's action pill must be DESTRUCTIVE, any other the accent (null)");
            return false;
        }
        return true;
    }

    // Stand-in fonts: 11 px per character for FONT_TINY and 8 for
    // FONT_XTINY, about the fēnix 7 Pro's (UiTests.Fixed, OnboardingTests).
    class CharWidth {
        private var _px as Number;

        function initialize(px as Number) {
            _px = px;
        }

        function width(s as String) as Number {
            return s.length() * _px;
        }
    }

    function _layout(text as String) as [Graphics.FontType, Number, Array<String>] {
        var g = GeoTests.fenix7pro();
        return CommandConfirm.questionLines(text, g, g.heroBottom - g.px(CommandConfirm.QUESTION_GAP),
            (new CharWidth(11)).method(:width), (new CharWidth(8)).method(:width));
    }

    function _joined(lines as Array<String>) as String {
        var s = "";
        for (var i = 0; i < lines.size(); i += 1) {
            s += (i > 0 ? " " : "") + (lines[i] as String);
        }
        return s;
    }

    // The question sits in the title area, whole, on the fēnix 7 Pro: a
    // short one on one line, the auxiliary heater's in two, and the
    // longest charge mode's in two smaller lines rather than cut.
    (:test)
    function questionFitsWhole(logger as Logger) as Boolean {
        var short = _layout("Stop charging?");
        if (short[2].size() != 1 || short[0] != Graphics.FONT_TINY) {
            logger.error("\"Stop charging?\" must stay on one FONT_TINY line");
            return false;
        }
        var aux = "Start the auxiliary heater?";
        var two = _layout(aux);
        if (two[2].size() != 2 || two[0] != Graphics.FONT_TINY || !_joined(two[2]).equals(aux)) {
            logger.error("the auxiliary heater's question must take two whole FONT_TINY lines, got \"" + _joined(two[2]) + "\"");
            return false;
        }
        var mode = "Set mode to Immediate discharging?";
        var small = _layout(mode);
        if (small[2].size() != 2 || small[0] != Graphics.FONT_XTINY || !_joined(small[2]).equals(mode)) {
            logger.error("the longest mode question must take two whole FONT_XTINY lines, got \"" + _joined(small[2]) + "\"");
            return false;
        }
        return true;
    }

}
