import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

// US-003's guidance screen, and: when settings are syntactically present
// but this exact key has never had a successful request: the "on first
// request" validator US-002 asks for. Both live in one class because they
// share almost everything: the layout, the "Clear stored data" escape
// hatch, and (for the validating case) the transient-error sub-state. See
// ui/OnboardingGate.mc for what decides which mode a launch starts in.
//
// Never looks like an error or a crash (US-003): even the validating and
// failed-but-not-onboarding's-concern states read as plain, calm text, not
// a red banner or a stack trace.
class OnboardingView extends WatchUi.View {

    // true: settings are syntactically fine and this key has never
    // validated, so onShow() fires the one validating request US-002 asks
    // for. false: nothing to check yet (US-003). Key/VIN missing, or the
    // VIN fails Settings.isVinValid().
    private var _validating as Boolean;
    // Set only when a validation attempt failed for a reason onboarding
    // does not have a dedicated screen for (e.g. the quota is spent, the
    // phone is unreachable, a 5xx): shown in place with a manual retry.
    // US-002: "never retry automatically". This is that rule enforced by
    // construction: nothing here re-fires the request without a select
    // press reaching retry() below.
    private var _transientError as String?;
    // A validation request is on its way. onShow() fires again whenever
    // something pushed on top (the action menu, the clear confirmation)
    // pops, and a second request would spend quota for the same answer.
    private var _inFlight as Boolean = false;
    private var _screen as OnboardingText;
    // Garmin's action menu indicator stands in for MENU on watches without
    // that key (Input.enableIndicator); while it shows, the text keeps
    // clear of it (Geo.setKeepOut in onShow).
    private var _indicator as Boolean;

    function initialize(validating as Boolean) {
        View.initialize();
        _validating = validating;
        _transientError = null;
        _screen = new OnboardingText();
        _indicator = Input.enableIndicator(self);
    }

    // No setLayout() here. These messages are whole sentences, and
    // WatchUi.Text does not wrap: :width bounds justification, not layout,
    // so the string was drawn as one line running off both edges of the
    // round face. OnboardingText wraps it to the chord at each line's height.
    function onLayout(dc as Dc) as Void {
    }

    // The text is loaded here and on every state change, never in onUpdate()
    // (A22, docs/best-practices "Never load resources inside onUpdate()").
    // The validating request is fired from onShow(), not onLayout() or the
    // constructor: it is I/O and must only happen once this screen is
    // actually the one on top.
    function onShow() as Void {
        Theme.refresh();
        Geo.setKeepOut(_indicator);
        _refreshText();
        if (Onboarding.shouldValidate(_validating, _transientError != null, _inFlight)) {
            _startValidation();
        }
    }

    function onUpdate(dc as Dc) as Void {
        _screen.draw(dc);
    }

    // A manual retry only: called by OnboardingDelegate's onSelect() while
    // a transient error is showing. Never called from within
    // _onValidationResponse() itself.
    function retry() as Void {
        _transientError = null;
        _refreshText();
        _startValidation();
    }

    // Guidance mode's primary action: push go.skoda.eu/api-keys to the
    // phone browser. Fire-and-forget, no callback: Communications.
    // openWebPage() offers none, so this never blocks or gates anything
    // else on the page having actually opened.
    function openKeyPage() as Void {
        Communications.openWebPage(WatchUi.loadResource(Rez.Strings.OnboardingKeyPageUrl) as String, null, null);
    }

    function isValidating() as Boolean {
        return _validating;
    }

    function hasTransientError() as Boolean {
        return _transientError != null;
    }

    // Text and bezel glyphs for the current state, loaded once per state
    // change (A22). The menu glyph replaces the old "Menu for more."
    // wherever MENU is the way on (guidance, a failed check); guidance also
    // shows the check at START (open the key page), since touch watches have
    // no labelled START. A failed check shows no check: START retries there,
    // which spends quota, so it is not advertised. The check in progress
    // shows none, as in the PoC (NO.text "check").
    function _refreshText() as Void {
        var error = _transientError;
        if (error != null) {
            _screen.set(error, true, false);
        } else if (_validating) {
            _screen.set(WatchUi.loadResource(Rez.Strings.OnboardingCheckingMessage) as String, false, false);
        } else {
            _screen.set(WatchUi.loadResource(Rez.Strings.OnboardingGuidanceMessage) as String, true, true);
        }
        WatchUi.requestUpdate();
    }

    // US-002: validation is "nearly free" (401/403 don't consume quota) but
    // a SUCCESS does, at the same cost as any other read, so this checks
    // the app's own quota estimate first rather than spending it on a
    // request that would only report back what Quota.mc already knows.
    function _startValidation() as Void {
        if (!Quota.canSpend()) {
            // Nothing new to learn from spending the request just to be
            // told the same thing Quota.mc already knows locally, and a
            // 429 here would look identical to a real one anyway.
            _transientError = WatchUi.loadResource(Rez.Strings.OnboardingQuotaBlockedMessage) as String;
            _refreshText();
            return;
        }
        var settings = getApp().getSettings();
        _inFlight = true;
        // include=status: this call exists to validate the key/VIN pair,
        // not to fetch a screen's worth of data: same quota cost either
        // way (see mock/README.md), less to receive and discard.
        ApiClient.getVehicle(settings.vin, "status", settings.apiKey, method(:_onValidationResponse));
    }

    function _onValidationResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _inFlight = false;
        var settings = getApp().getSettings();

        if (responseCode >= 200 && responseCode < 300) {
            // US-004: the only place a key's estimated start date is ever
            // set: the first successful request, exactly as the story
            // asks for.
            KeyLifetime.recordSuccess(settings.apiKey);
            HomeScreen.switchTo();
            return;
        }

        var body = (data instanceof Dictionary) ? data as Dictionary : null;
        var blocked = Onboarding.viewForProblem(responseCode, body);
        if (blocked != null) {
            WatchUi.switchToView(blocked, new OnboardingDelegate(blocked), WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        // Not one of onboarding's four causes (e.g. a spent quota, the
        // phone unreachable, a 5xx): ProblemDetail already has a good
        // message for it; show it in place with a manual retry rather than
        // inventing a second copy of that wording.
        var message = ProblemDetail.describe(responseCode, body, null);
        _transientError = message.text;
        _refreshText();
    }

}

// C7 text layout, pure (takes the display and the measuring callback, like
// TextBlock), so the fit is tested for every screen without a Dc. Wraps on
// the outline at each line's height with an extra margin when a bezel glyph
// is shown, so no line runs into it; the larger font only while the text
// fits in four lines. Mirrors obLayout() in tools/ui/devices/40-screens.js,
// except that text running past the outline even in FONT_XTINY is cut with
// "…" here instead of split into parts (paging is open, M14).
module OnboardingLayout {

    // Margins in px of the 260 face (Geo scales them): Theme.RING_MARGIN
    // without glyphs; 26 keeps lines clear of a glyph at the glyph radius
    // next to UP, BACK or START (PoC NO.text).
    const MARGIN = 12;
    const GLYPH_MARGIN = 26;
    const MAX_SMALL_LINES = 4;
    // Narrowest slot a line may use, in px of the 260 face: below it a word
    // would break mid-word in the round edge (obLayout's fin.w >= 40).
    const MIN_SLOT_W = 40;

    // Margin for a screen with these glyphs.
    function marginFor(menu as Boolean, check as Boolean) as Number {
        return (menu || check) ? GLYPH_MARGIN : MARGIN;
    }

    // Top y of a block of `slots` lines centred on the face.
    function top(g as Geo.Display, slots as Number, lineHeight as Number) as Number {
        return g.cy - (slots * lineHeight) / 2;
    }

    function widths(g as Geo.Display, slots as Number, lineHeight as Number, margin as Number) as Array<Number> {
        var out = [] as Array<Number>;
        var t = top(g, slots, lineHeight);
        for (var i = 0; i < slots; i += 1) {
            out.add(Ui.usableIn(g, t + i * lineHeight, t + (i + 1) * lineHeight, margin));
        }
        return out;
    }

    // Line count and per-line widths depend on each other (a taller block
    // narrows its outer lines), so iterate to a fixed point. Returns the lines
    // and the slot count they were wrapped for: when the last pass came out a
    // line short, the lines keep the slots they were measured in rather than
    // being re-centred into slots they were never checked against. Stops
    // growing past maxLines: slots beyond the face have no chord, and the
    // caller rejects such a layout anyway.
    function wrap(g as Geo.Display, text as String, lineHeight as Number, margin as Number, maxLines as Number,
                  measure as Method(s as String) as Number) as [Array<String>, Number] {
        var count = 1;
        var lines = [] as Array<String>;
        for (var pass = 0; pass < 8; pass += 1) {
            lines = TextBlock.wrapLines(text, widths(g, count, lineHeight, margin), measure);
            if (lines.size() <= count) {
                break;
            }
            count = lines.size();
            if (count > maxLines) {
                break;
            }
        }
        if (lines.size() == 0) {
            count = 0;
        }
        return [lines, count];
    }

    // Whether wrapped lines can be drawn as they are: no more lines than
    // slots, the block clear of the ring at the top, every slot wide enough
    // and every line inside its slot.
    function fits(g as Geo.Display, lines as Array<String>, slots as Number, lineHeight as Number,
                  margin as Number, measure as Method(s as String) as Number) as Boolean {
        if (lines.size() > slots || slots * lineHeight > g.h || top(g, slots, lineHeight) < g.minDigitTop) {
            return false;
        }
        var w = widths(g, slots, lineHeight, margin);
        var minW = g.px(MIN_SLOT_W);
        for (var i = 0; i < lines.size(); i += 1) {
            if ((w[i] as Number) < minW || measure.invoke(lines[i] as String) > (w[i] as Number)) {
                return false;
            }
        }
        return true;
    }

    // C7: FONT_SMALL when the text fits in four lines, else FONT_XTINY.
    function useSmall(smallLineCount as Number) as Boolean {
        return smallLineCount <= MAX_SMALL_LINES;
    }

    // The most xtiny slots that fit (fits() for a block of that many full
    // lines), at least one.
    function maxSlots(g as Geo.Display, lineHeight as Number, margin as Number) as Number {
        var minW = g.px(MIN_SLOT_W);
        var best = 1;
        for (var n = 1; n <= g.h / lineHeight; n += 1) {
            if (top(g, n, lineHeight) < g.minDigitTop) {
                break;
            }
            var w = widths(g, n, lineHeight, margin);
            var ok = true;
            for (var i = 0; i < n; i += 1) {
                if ((w[i] as Number) < minW) {
                    ok = false;
                    break;
                }
            }
            if (!ok) {
                break;
            }
            best = n;
        }
        return best;
    }

    // The layout a screen draws: [lines, slots, small?]. Small first, xtiny
    // when small needs more than four lines. Text that does not fit even in
    // xtiny (long copy on a large screen with large fonts, such as "Key
    // expired" on vívoactive 6 / Venu 4) fills the most slots that fit and
    // its last line ends in "…"; paging it is an open decision (M14).
    function choose(g as Geo.Display, text as String, margin as Number,
                    smallHeight as Number, smallMeasure as Method(s as String) as Number,
                    xtinyHeight as Number, xtinyMeasure as Method(s as String) as Number)
                    as [Array<String>, Number, Boolean] {
        var small = wrap(g, text, smallHeight, margin, MAX_SMALL_LINES, smallMeasure);
        if (useSmall(small[0].size()) && fits(g, small[0], small[1], smallHeight, margin, smallMeasure)) {
            return [small[0], small[1], true];
        }
        var xtiny = wrap(g, text, xtinyHeight, margin, g.h / xtinyHeight, xtinyMeasure);
        if (fits(g, xtiny[0], xtiny[1], xtinyHeight, margin, xtinyMeasure)) {
            return [xtiny[0], xtiny[1], false];
        }
        var n = maxSlots(g, xtinyHeight, margin);
        return [Ui.wrapFit(text, widths(g, n, xtinyHeight, margin), n, xtinyMeasure), n, false];
    }

}

// The drawing half every onboarding screen shares: black canvas, the wrapped
// text centred, and the bezel glyphs for the ways on: the MENU glyph routed
// by input profile (Bezel.menuGlyph, M9: UP, grey at BACK, or Garmin's
// indicator) and a check with the accent arc at START. Holds the text it was
// given and caches the layout until the text, the glyphs or the indicator
// keep-out change, so onUpdate() only measures once per text.
class OnboardingText {

    private var _text as String = "";
    private var _menu as Boolean = false;
    private var _check as Boolean = false;
    private var _lines as Array<String>? = null;
    private var _keepOut as Boolean = false;
    private var _slots as Number = 0;
    private var _font as Graphics.FontType = Graphics.FONT_SMALL;

    function initialize() {
    }

    // menu: MENU opens the onboarding menu (guidance, a failed check, a
    // blocked key). check: START continues (guidance opens the key page,
    // the expiry notice goes home); touch watches have no labelled START,
    // so the glyph is the only hint there. Neither while the key is checked.
    function set(text as String, menu as Boolean, check as Boolean) as Void {
        if (!text.equals(_text) || menu != _menu || check != _check) {
            _text = text;
            _menu = menu;
            _check = check;
            _lines = null;
        }
    }

    function draw(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        var g = Geo.current();
        var lines = _lines;
        if (lines == null || _keepOut != g.keepOut) {
            lines = _layout(dc, g);
        }
        var lh = dc.getFontHeight(_font);
        var y = OnboardingLayout.top(g, _slots, lh);
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(g.cx, y + i * lh, _font, lines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_menu) {
            Bezel.menuGlyph(dc, Theme.TEXT_1);
        }
        if (_check) {
            Bezel.glyphAt(dc, :start, :check, Theme.ACCENT, :accent);
        }
    }

    function _layout(dc as Dc, g as Geo.Display) as Array<String> {
        var result = OnboardingLayout.choose(g, _text, OnboardingLayout.marginFor(_menu, _check),
            dc.getFontHeight(Graphics.FONT_SMALL), Ui.measurer(dc, Graphics.FONT_SMALL),
            dc.getFontHeight(Graphics.FONT_XTINY), Ui.measurer(dc, Graphics.FONT_XTINY));
        _font = result[2] ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
        _lines = result[0];
        _slots = result[1];
        _keepOut = g.keepOut;
        return result[0];
    }

}
