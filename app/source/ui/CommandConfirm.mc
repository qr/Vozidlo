import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// The confirmation before a command (US-062), opened only by
// ConfirmationPolicy.run(), so the three callers (home, the charge limit and
// the charge mode) never see it. Since it shows before every command it is
// the screen users see most, so it is a NightMenu in the app's own style
// (PoC NH.confirm) rather than Garmin's WatchUi.Confirmation, which cannot
// be recoloured. A CustomMenu keeps Garmin's scrolling, focus, button and
// touch handling on every input profile.
//
// Layout: the question in the title area, up to two lines; the action
// ("Stop charging") as row 0 with the focus; "Cancel" as row 1. Row 0 keeps
// the question in view: on the button watches NightMenu masks the title as
// soon as the focus is on row 1 or lower (NightMenuLayout.maskBands). With
// the action focused, confirming is one more press of the same button.
//
// What that means for the repeated tap that prompted this screen: a second
// START, or a second tap where home's focused row was, lands on the action.
// So a pick of the action in the first PICK_GUARD_MS after the screen
// opened is ignored, which stops a double tap or a double press: its second
// half comes a few hundred ms after the first, and reading the question and
// choosing takes longer than that. It does not stop someone who keeps
// pressing or tapping: the first press after the guard sends. A tap where
// home's row above the focus was lands on the question and does nothing;
// one where the row below was lands on Cancel. None of this is measured:
// the simulator here draws no panel. Owner's choice, 2026-10-27, over
// Cancel focused (decisions.md "Every command is confirmed, unless the user
// switches it off.").
module CommandConfirm {

    const CANCEL as Symbol = :cancel;
    const SEND as Symbol = :send;
    const CANCEL_LABEL = "Cancel";
    const PICK_GUARD_MS = 500;
    // Gap between the question's last line and the rule above row 0, px of
    // the 260 face.
    const QUESTION_GAP = 6;

    // Pushed with Theme.SLIDE_DIALOG, like every confirmation.
    function open(action as Symbol, question as String,
                  send as ConfirmationPolicy.SendCommand, announce as ConfirmationPolicy.Announce) as Void {
        var menu = new CommandConfirmMenu(question, actionLabel(action), isStop(action));
        WatchUi.pushView(menu, new CommandConfirmDelegate(send, announce), Theme.SLIDE_DIALOG);
    }

    // The action row: the same words as the home row that sends it
    // (ControlTiles), so the row reads as "do what I picked". The charge
    // limit and mode carry their value in the question only: "Set mode to
    // Immediate discharging" does not fit a row on any round watch.
    function actionLabel(action as Symbol) as String {
        if (action == ConfirmationPolicy.START_CLIMATE) {
            return "Start climate";
        }
        if (action == ConfirmationPolicy.STOP_CLIMATE) {
            return "Stop climate";
        }
        if (action == ConfirmationPolicy.START_VENTILATION) {
            return "Start ventilation";
        }
        if (action == ConfirmationPolicy.STOP_VENTILATION) {
            return "Stop ventilation";
        }
        if (action == ConfirmationPolicy.START_AUX_HEATING) {
            return "Start aux heat";
        }
        if (action == ConfirmationPolicy.STOP_AUX_HEATING) {
            return "Stop aux heat";
        }
        if (action == ConfirmationPolicy.START_CHARGING) {
            return "Start charging";
        }
        if (action == ConfirmationPolicy.STOP_CHARGING) {
            return "Stop charging";
        }
        if (action == ConfirmationPolicy.SET_CHARGE_LIMIT) {
            return "Set limit";
        }
        if (action == ConfirmationPolicy.SET_CHARGE_MODE) {
            return "Set mode";
        }
        return "Send";
    }

    // Stop commands get a red action pill (Theme.DESTRUCTIVE), by the
    // owner's choice of 2026-10-27: they end something running. The charge
    // limit and mode change a setting and keep the accent, like the starts.
    function isStop(action as Symbol) as Boolean {
        return action == ConfirmationPolicy.STOP_CLIMATE || action == ConfirmationPolicy.STOP_VENTILATION
            || action == ConfirmationPolicy.STOP_AUX_HEATING || action == ConfirmationPolicy.STOP_CHARGING;
    }

    // Whether a pick of the action row counts, elapsedMs after the screen
    // opened. The difference of two System.getTimer() values stays right
    // across the timer's wrap; it is only negative after the screen has been
    // open for more than about 24.8 days, and that is not a double tap.
    function acceptsSend(elapsedMs as Number) as Boolean {
        return elapsedMs < 0 || elapsedMs >= PICK_GUARD_MS;
    }

    // The question as it is drawn, bottom-aligned on `bottom` (screen y),
    // each line fitted to the outline at its own height: one FONT_TINY line
    // where it fits, else two, else two in FONT_XTINY, the second cut with
    // "…" only if even those do not hold it (Ui.wrapFit). Returns
    // [font, line height, lines]. "Start the auxiliary heater?" needs two
    // lines on every watch, where the NightMenu title's single line would
    // cut it; "Set mode to Immediate discharging?" needs XTINY on every
    // watch (PoC NH.confirm, fitcheck --devices). The wider margin is the
    // 12 px the design checks hold the PoC to: with 8, that question ran
    // closer to the edge on the X1.
    function questionLines(text as String, g as Geo.Display, bottom as Number,
                           tiny as Method(s as String) as Number,
                           xtiny as Method(s as String) as Number) as [Graphics.FontType, Number, Array<String>] {
        var lineH = g.fonts.tinyH;
        var oneTop = bottom - lineH;
        var oneW = g.usable(oneTop, bottom, Theme.RING_MARGIN);
        if (tiny.invoke(text) <= oneW) {
            return [Graphics.FONT_TINY, lineH, [text] as Array<String>];
        }
        var widths = [g.usable(oneTop - lineH, oneTop, Theme.RING_MARGIN), oneW] as Array<Number>;
        var lines = TextBlock.wrapLines(text, widths, tiny);
        if (lines.size() <= 2) {
            return [Graphics.FONT_TINY, lineH, lines];
        }
        lineH = g.fonts.xtinyH;
        oneTop = bottom - lineH;
        widths = [g.usable(oneTop - lineH, oneTop, Theme.RING_MARGIN), g.usable(oneTop, bottom, Theme.RING_MARGIN)] as Array<Number>;
        return [Graphics.FONT_XTINY, lineH, Ui.wrapFit(text, widths, 2, xtiny)];
    }

}

// Home's own trick (HomeMenu): the title area runs down to the focused row
// (titleHeight Geo heroBottom), so the question has the room of a hero. It
// is drawn at every focus, like NightMenu's title, so it scrolls out with
// the list; from row 1 on the mask covers it on the button watches.
class CommandConfirmMenu extends NightMenu {

    private var _question as String;

    function initialize(question as String, actionLabel as String, stop as Boolean) {
        NightMenu.initialize(question, 0, Geo.current().heroBottom);
        _question = question;
        var send = new NightMenuItem(CommandConfirm.SEND, actionLabel, null, null, null);
        // Red carries no "!" here, unlike everywhere else: "!" means a
        // failure or a warning, and a stop is neither. The word "Stop" is
        // the first signal, the colour the second.
        if (stop) {
            send.setPill(Theme.DESTRUCTIVE);
        }
        addItem(send);
        addItem(new NightMenuItem(CommandConfirm.CANCEL, CommandConfirm.CANCEL_LABEL, null, null, null));
    }

    // Accent text with the 1 px rule under it, as NightMenu's title, but in
    // up to two lines (CommandConfirm.questionLines).
    function drawTitle(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        var g = Geo.current();
        var h = dc.getHeight();
        var w = dc.getWidth();
        // Screen y of this dc's top at focus 0: its bottom is heroBottom.
        var offset = g.heroBottom - h;
        var bottom = g.heroBottom - g.px(CommandConfirm.QUESTION_GAP);
        var layout = CommandConfirm.questionLines(_question, g, bottom,
            Ui.measurer(dc, Graphics.FONT_TINY), Ui.measurer(dc, Graphics.FONT_XTINY));
        var font = layout[0];
        var lineH = layout[1];
        var lines = layout[2];
        var n = lines.size();
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < n; i += 1) {
            var top = bottom - (n - i) * lineH - offset;
            dc.drawText(w / 2, top, font, lines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - g.px(70), h - 2, g.px(140), 1);
    }

}

// Only ever constructed by CommandConfirm.open(): never holds a
// back-reference to a view, so there is no A->B->A cycle to break with
// weak() here (docs/best-practices). The menu stays up on a pick
// (popOnSelect false) so an ignored pick leaves it on screen; the delegate
// pops it itself. Every way out other than the action row sends nothing.
// It answers once, as Garmin's Confirmation did: a second pick or BACK that
// arrives before the pop has taken effect would otherwise pop the screen
// under it too (on home that closes the app) and send a second time.
class CommandConfirmDelegate extends NightMenuDelegate {

    private var _send as ConfirmationPolicy.SendCommand;
    private var _announce as ConfirmationPolicy.Announce;
    private var _openedAt as Number;
    private var _answered as Boolean = false;

    function initialize(send as ConfirmationPolicy.SendCommand, announce as ConfirmationPolicy.Announce) {
        NightMenuDelegate.initialize(false);
        _send = send;
        _announce = announce;
        _openedAt = System.getTimer();
    }

    // Pops before sending, so "Command sent" and the toast land on the
    // screen the command came from (A14).
    // The guards ran when the screen opened, which can be a while ago: the
    // check after an earlier command may have spent the quota since, or the
    // phone may have gone. So they run again on Yes, and a refusal says why
    // the same way the charging menus do (a command in flight stays silent).
    function onPick(id as Object?) as Void {
        if (_answered) {
            return;
        }
        if (id == CommandConfirm.SEND) {
            if (!CommandConfirm.acceptsSend(System.getTimer() - _openedAt)) {
                return;
            }
            _answered = true;
            WatchUi.popView(Theme.SLIDE_DIALOG);
            var verdict = Refusal.current(CommandFlight.busy());
            if (verdict != :ok) {
                Refusal.toast(Refusal.commandText(verdict, Quota.secondsUntilReset()));
                return;
            }
            ConfirmationPolicy.sendAndAnnounce(_send, _announce);
        } else if (id == CommandConfirm.CANCEL) {
            _answered = true;
            WatchUi.popView(Theme.SLIDE_DIALOG);
        }
    }

    // BACK is always "no", and leaves as the dialog came in.
    function onBack() as Void {
        if (_answered) {
            return;
        }
        _answered = true;
        WatchUi.popView(Theme.SLIDE_DIALOG);
    }

}
