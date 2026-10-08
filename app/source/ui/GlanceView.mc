import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

// US-034/US-035: AppBase.getGlanceView() implementation, see
// VozidloApp.getGlanceView() for the wiring. Shows state of charge, lock,
// charging and climate state straight from Cache.mc, with an age indicator,
// and NOTHING else: WatchUi.GlanceView has no input delegate. Garmin's own
// doc says it is "prohibited from using page control functionality", so
// this file only draws, it never acts. Selecting the glance in the
// carousel falls straight through to AppBase.getInitialView(), which
// lands on the home screen with the primary action focused (US-037);
// there is nothing to wire for that here, only not to break it.
//
// HARD CONSTRAINT: no web request, in any code path, ever (US-034). Every
// value below comes from Cache.mc, which is itself Storage-backed and
// makes no request of its own; nothing in this file imports
// Toybox.Communications or references ApiClient.
//
// (:glance): every symbol reachable from glance mode must carry this
// annotation to be compiled into the glance arena (65,536 B on this
// device), see the SDK's Backgrounding doc: "Only modules, classes,
// functions and member variables decorated with the annotation will be
// compiled into" that restricted context (Glances documents the identical
// rule for :glance).
//
// Read "will be compiled into" literally. An unannotated symbol is not in
// the glance binary at all, so calling it is not a budget risk, it is a
// guaranteed runtime crash: "Illegal Access (Out of Bounds). Failed
// invoking <symbol>". This file once carried
// (:typecheck(disableGlanceCheck)) on onShow() and onUpdate() to silence
// the compiler's warning about calling into the then-unannotated
// model/Cache.mc and ui/StateIcons.mc, on the reasoning that both are
// cheap. Both are cheap. The glance crashed anyway, on every launch, until
// those two modules were annotated (:glance) themselves. See VozidloApp.mc
// for the same mistake in onStart(). Annotating a module is enough; its
// members follow.
//
// So the Night Panel layout (C6) draws only through glance-safe modules:
// Theme, Age, Labels, StateIcons, Cache. Ui, Bezel, NightIcons and Chips are
// app scope (they keep the glance arena small) and must never be called here.
(:glance)
module GlanceFormat {

    // True once there is anything at all worth drawing: false is exactly
    // the "no cached data" case US-034 requires an invitation for.
    function hasAnyData(soc as Object?, chargingState as Object?, locked as Object?) as Boolean {
        return soc != null || chargingState != null || locked != null;
    }

    // Digits and "%" only; a missing reading is the app-wide dash, never "0%".
    function socText(value as Object?) as String {
        if (value == null) {
            return Labels.DASH;
        }
        if (value instanceof Float) {
            return (value as Float).toNumber().toString() + "%";
        }
        return value.toString() + "%";
    }

    // Pixels of the SoC bar to fill (C6 row 3). Anything that is not a
    // number reads as empty rather than crashing: the cache copies enum-ish
    // and numeric fields through verbatim (Cache.mc), so a future API change
    // must not take the glance down.
    function barFill(value as Object?, width as Number) as Number {
        var pct = 0.0;
        if (value instanceof Number) {
            pct = (value as Number).toFloat();
        } else if (value instanceof Float) {
            pct = value as Float;
        } else {
            return 0;
        }
        if (pct < 0) {
            pct = 0.0;
        }
        if (pct > 100) {
            pct = 100.0;
        }
        return Math.round(width * pct / 100.0).toNumber();
    }

    // Trim `text` until it fits `maxWidth`, marking the cut. A glance is a
    // narrow band and the strings here are built from whatever the API
    // returned, so an unrecognised state value can be far longer than
    // anything anticipated. `measure` is passed in rather than a Dc so this
    // is testable without graphics. Ui.fit() does the same for the app, but
    // Ui is app scope, so the glance keeps this copy.
    function truncated(text as String, maxWidth as Number,
                       measure as Method(s as String) as Number) as String {
        if (maxWidth <= 0) {
            return "";
        }
        if (measure.invoke(text) <= maxWidth) {
            return text;
        }
        var shown = text;
        while (shown.length() > 1 && measure.invoke(shown + Labels.ELLIPSIS) > maxWidth) {
            shown = shown.substring(0, shown.length() - 1) as String;
        }
        return shown + Labels.ELLIPSIS;
    }

    // The newer (smaller-age / more-recent) of two section ages, tolerating
    // either or both being unknown: US-034 wants ONE age indicator for the
    // glance, not one per section.
    function newerAge(a as Number?, b as Number?) as Number? {
        if (a == null) {
            return b;
        }
        if (b == null) {
            return a;
        }
        return (a > b) ? a : b;
    }

    // US-034's age indicator in the chip form ("Just now", "5 min", "2 h"):
    // the glance has no room for "ago" (B4 copy rule). Stale gets "! " in
    // front so it survives the monochrome test, as Age.line() does.
    // Empty when nothing was ever captured, so no bogus age is drawn.
    function ageText(capturedAtSeconds as Number?, nowSeconds as Number) as String {
        var elapsed = Age.elapsed(capturedAtSeconds, nowSeconds);
        if (elapsed == null) {
            return "";
        }
        if (Age.isStale(elapsed)) {
            return "! " + Age.short(elapsed);
        }
        return Age.short(elapsed);
    }

}

(:glance)
class VozidloGlanceView extends WatchUi.GlanceView {

    // Side padding inside the 171 px content area (PoC NG.content X = 6).
    private const PAD = 6;
    // Row 1 top and the SoC bar (C6: row 1 y 2, 4 px bar 8 px above the bottom).
    private const ROW1_Y = 2;
    private const BAR_H = 4;
    private const BAR_BOTTOM_GAP = 8;
    // Row 2 icons: r 8, centre 13 px after the SoC, text 11 px after the
    // lock icon's centre, 12 px between the label and the next icon (PoC).
    private const ICON_R = 8;
    private const ICON_GAP = 13;
    private const ICON_TEXT = 11;
    private const ICON_STEP = 20;

    private const APP_NAME as String = "Vozidlo";
    private const INVITATION as String = "Open for your car";

    private var _hasData as Boolean = false;
    private var _socText as String = "";
    private var _socRaw as Object? = null;
    private var _lockText as String = "";
    private var _ageText as String = "";
    private var _stale as Boolean = false;
    private var _insecure as Boolean = false;
    private var _charging as Boolean = false;
    // US-059: the same state icons as the home screen and Status. A literal
    // default so the initializer resolves before onShow() has run.
    private var _lockIcon as Symbol = :unknown;
    private var _chargeIcon as Symbol? = null;
    private var _climateIcon as Symbol? = null;

    function initialize() {
        GlanceView.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    // Rebuilt every time the glance becomes visible: Cache.mc is
    // Storage-backed and effectively instant, and this is the ONLY place this
    // file touches Cache.mc; onUpdate() only measures and draws
    // (docs/best-practices, "Pre-compute, then draw").
    function onShow() as Void {
        Theme.refresh();
        var charging = Cache.section("charging");
        var status = Cache.section("status");
        var climate = Cache.section("airConditioning");

        var soc = (charging != null) ? charging.get("batterySocPercent") : null;
        var chargingState = (charging != null) ? (charging.get("state") as String?) : null;
        var locked = (status != null) ? (status.get("doorsLocked") as String?) : null;
        var climateState = (climate != null) ? (climate.get("state") as String?) : null;

        _hasData = GlanceFormat.hasAnyData(soc, chargingState, locked);
        _socRaw = soc;
        _socText = GlanceFormat.socText(soc);
        _lockIcon = StateIcons.forLockStatus(locked);
        _lockText = Labels.lock(locked);
        _insecure = Labels.isInsecureLock(locked);
        _chargeIcon = StateIcons.forChargingStatus(chargingState);
        _climateIcon = StateIcons.forClimateStatus(climateState);
        _charging = chargingState != null && chargingState.equals("CHARGING");

        var captured = GlanceFormat.newerAge(Cache.sectionAge("charging"), Cache.sectionAge("status"));
        var now = Time.now().value();
        _ageText = _hasData ? GlanceFormat.ageText(captured, now) : "";
        var elapsed = Age.elapsed(captured, now);
        _stale = elapsed != null && Age.isStale(elapsed);
    }

    // C6, three rows in the glance's own dc (171 x 63 on fenix7pro):
    //   row 1  "Vozidlo" grey left, age right ("12 min", amber "! 17 h")
    //   row 2  "100%" tiny, padlock + "Locked", charging and climate icons
    //   row 3  4 px SoC bar: track RULE, fill white, accent while charging
    // Empty cache: the name and "Open for your car" (US-034: never blank).
    // Row heights come from the fonts, so fēnix 8/9 font scaling moves row 2
    // down instead of overlapping row 1.
    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var xtiny = Graphics.FONT_XTINY;
        var tiny = Graphics.FONT_TINY;
        var row2Y = ROW1_Y + dc.getFontHeight(xtiny) + 1;
        var right = w - PAD;

        dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
        dc.drawText(PAD, ROW1_Y, xtiny, APP_NAME, Graphics.TEXT_JUSTIFY_LEFT);

        if (!_hasData) {
            var invite = GlanceFormat.truncated(INVITATION, right - PAD, (new GlanceMetrics(dc, tiny)).method(:width));
            dc.drawText(PAD, row2Y, tiny, invite, Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        // Row 1: the age, right-aligned, never over the name.
        if (_ageText.length() > 0) {
            var nameW = dc.getTextWidthInPixels(APP_NAME, xtiny);
            var age = GlanceFormat.truncated(_ageText, right - PAD - nameW - 6,
                (new GlanceMetrics(dc, xtiny)).method(:width));
            dc.setColor(Theme.c(_stale ? Theme.WARNING : Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
            dc.drawText(right, ROW1_Y, xtiny, age, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Row 2: SoC, lock icon + word, then the charging and climate icons.
        var mid = row2Y + dc.getFontHeight(tiny) / 2;
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        dc.drawText(PAD, row2Y, tiny, _socText, Graphics.TEXT_JUSTIFY_LEFT);

        var trailing = 0;
        if (_chargeIcon != null) {
            trailing += 1;
        }
        if (_climateIcon != null) {
            trailing += 1;
        }
        // Room the trailing icons need right of the label: each takes a 12 px
        // gap plus its 8 px half-size, i.e. one ICON_STEP.
        var trailingW = trailing * ICON_STEP;

        var x = PAD + dc.getTextWidthInPixels(_socText, tiny) + ICON_GAP;
        // Unlocked/open in amber with its own icon shape (B3: never colour alone).
        var lockColor = Theme.c(_insecure ? Theme.WARNING : Theme.TEXT_1);
        StateIcons.draw(dc, _lockIcon, x, mid, ICON_R, lockColor);
        x += ICON_TEXT;
        var lock = GlanceFormat.truncated(_lockText, right - trailingW - x,
            (new GlanceMetrics(dc, tiny)).method(:width));
        dc.setColor(lockColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, row2Y, tiny, lock, Graphics.TEXT_JUSTIFY_LEFT);
        x += dc.getTextWidthInPixels(lock, tiny) + (ICON_STEP - ICON_R);

        var white = Theme.c(Theme.TEXT_1);
        var chargeIcon = _chargeIcon;
        if (chargeIcon != null) {
            StateIcons.draw(dc, chargeIcon, x, mid, ICON_R, white);
            x += ICON_STEP;
        }
        var climateIcon = _climateIcon;
        if (climateIcon != null) {
            StateIcons.draw(dc, climateIcon, x, mid, ICON_R, white);
        }

        // Row 3: SoC bar. Fill white, accent only while charging, like the rings.
        var barY = h - BAR_BOTTOM_GAP;
        var barW = right - PAD;
        var fill = GlanceFormat.barFill(_socRaw, barW);
        if (fill < barW) {
            dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(PAD + fill, barY, barW - fill, BAR_H);
        }
        if (fill > 0) {
            dc.setColor(Theme.c(_charging ? Theme.ACCENT : Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(PAD, barY, fill, BAR_H);
        }
    }

}

// Wraps a Dc and a font so text measurement can be passed as a Method, which
// is what lets GlanceFormat.truncated() be tested with arithmetic instead of
// graphics. (:glance) because the glance binary only contains annotated code:
// an unannotated symbol is absent, not merely discouraged, and calling it
// crashes. Ui.Measure does the same for the app, but Ui is app scope.
(:glance)
class GlanceMetrics {
    private var _dc as Dc;
    private var _font as Graphics.FontType;

    function initialize(dc as Dc, font as Graphics.FontType) {
        _dc = dc;
        _font = font;
    }

    function width(s as String) as Number {
        return _dc.getTextWidthInPixels(s, _font);
    }
}
