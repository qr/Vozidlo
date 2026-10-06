import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// US-034/US-035 (task 10): AppBase.getGlanceView() implementation, see
// VozidloApp.getGlanceView() for the wiring. Shows state of charge, charging
// state and lock state straight from Cache.mc, with an age indicator, and
// NOTHING else: WatchUi.GlanceView has no input delegate. Garmin's own
// doc says it is "prohibited from using page control functionality", so
// this file only draws, it never acts. Selecting the glance in the
// carousel falls straight through to AppBase.getInitialView(), which is
// what already lands on ControlsView with the primary tile preselected
// (US-037); there is nothing to wire for that here, only not to break it.
//
// HARD CONSTRAINT: no web request, in any code path, ever (US-034). Every
// value below comes from Cache.mc, which is itself Storage-backed and
// makes no request of its own; nothing in this file imports
// Toybox.Communications or references ApiClient. Verified two ways: by
// this code-inspection argument, and by watching mock/run.sh
// --log-requests log nothing while the simulator's glance renders, see
// the task's final report for both.
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
(:glance)
module GlanceFormat {

    const EM_DASH = "—";
    const ELLIPSIS = "…";

    // True once there is anything at all worth drawing: false is exactly
    // the "no cached data" case US-034 requires an invitation for.
    function hasAnyData(soc as Object?, chargingState as Object?, locked as Object?) as Boolean {
        return soc != null || chargingState != null || locked != null;
    }

    function socText(value as Object?) as String {
        if (value == null) {
            return EM_DASH;
        }
        if (value instanceof Float) {
            return (value as Float).toNumber().toString() + "%";
        }
        return value.toString() + "%";
    }

    function textOr(value as String?) as String {
        return (value != null) ? value : EM_DASH;
    }

    // Trim `text` until it fits `maxWidth`, marking the cut. A glance is a
    // narrow band and the strings here are built from whatever the API
    // returned, so an unrecognised state value can be far longer than
    // anything anticipated: the old code drew it straight and let it run off
    // the right edge. `measure` is passed in rather than a Dc so this is
    // testable without graphics, the same arrangement ui/TextBlock.mc uses.
    function truncated(text as String, maxWidth as Number,
                       measure as Method(s as String) as Number) as String {
        if (maxWidth <= 0) {
            return "";
        }
        if (measure.invoke(text) <= maxWidth) {
            return text;
        }
        var shown = text;
        while (shown.length() > 1 && measure.invoke(shown + ELLIPSIS) > maxWidth) {
            shown = shown.substring(0, shown.length() - 1) as String;
        }
        return shown + ELLIPSIS;
    }

    // Mirrors ControlsView._lockLabel(): duplicated rather than shared
    // because that method lives on a class this file has no reason to
    // depend on, and the mapping is three lines long.
    function lockText(raw as String?) as String {
        if (raw == null) {
            return EM_DASH;
        }
        if (raw.equals("YES")) {
            return "LOCKED";
        }
        if (raw.equals("NO")) {
            return "UNLOCKED";
        }
        return raw;
    }

    // The newer (smaller-age / more-recent) of two section ages, tolerating
    // either or both being unknown: US-034 wants ONE age indicator for the
    // glance's compact strip, not one per section.
    function newerAge(a as Number?, b as Number?) as Number? {
        if (a == null) {
            return b;
        }
        if (b == null) {
            return a;
        }
        return (a > b) ? a : b;
    }

    // US-034: "with an age indicator". Coarse buckets, not exact seconds,
    // matching the glance's small drawing area and low update-rate ceiling.
    // StatusView (task 6) is where an exact reading belongs.
    function ageText(capturedAtSeconds as Number?, nowSeconds as Number) as String {
        if (capturedAtSeconds == null) {
            return "";
        }
        var elapsed = nowSeconds - capturedAtSeconds;
        if (elapsed < 0) {
            elapsed = 0;
        }
        if (elapsed < 60) {
            return "just now";
        }
        if (elapsed < 3600) {
            return (elapsed / 60).toString() + " min ago";
        }
        if (elapsed < 86400) {
            return (elapsed / 3600).toString() + " h ago";
        }
        return (elapsed / 86400).toString() + " d ago";
    }

}

(:glance)
class VozidloGlanceView extends WatchUi.GlanceView {

    private var _hasData as Boolean = false;
    private var _summaryLine as String = "";
    private var _ageLine as String = "";
    // US-059: the same lock-state icon as ControlsView's top strip,
    // StatusView and the complications: resolved once in onShow(), same
    // as every other field on this class, so onUpdate() only ever draws.
    // Defaults to the plain :unknown symbol rather than StateIcons.UNKNOWN
    // so this field's initializer resolves without reaching across files at
    // all; StateIcons.mc is (:glance)-annotated now, but a literal is still
    // the cheaper thing to run before onShow() has filled this in.
    private var _lockIcon as Symbol = :unknown;

    function initialize() {
        GlanceView.initialize();
    }

    // Nothing needs `dc` up front, see ControlsView.onLayout()'s identical
    // reasoning. All drawing happens in onUpdate() from state built here in
    // onShow(), never inside onUpdate() itself (docs/best-practices,
    // "Never load resources inside onUpdate()" / "Pre-compute, then draw").
    function onLayout(dc as Dc) as Void {
    }

    // Rebuilt every time the glance becomes visible: Cache.mc is
    // Storage-backed and effectively instant (see ControlsView.onShow()'s
    // own comment on the same point), so this is cheap, and it is the ONLY
    // place this file touches Cache.mc; onUpdate() only draws.
    function onShow() as Void {
        var charging = Cache.section("charging");
        var status = Cache.section("status");

        var soc = (charging != null) ? charging.get("batterySocPercent") : null;
        var chargingState = (charging != null) ? (charging.get("state") as String?) : null;
        var locked = (status != null) ? (status.get("doorsLocked") as String?) : null;
        _lockIcon = StateIcons.forLockStatus(locked);

        _hasData = GlanceFormat.hasAnyData(soc, chargingState, locked);
        if (!_hasData) {
            _summaryLine = "";
            _ageLine = "";
            return;
        }

        var age = GlanceFormat.newerAge(Cache.sectionAge("charging"), Cache.sectionAge("status"));
        _summaryLine = GlanceFormat.socText(soc) + "  " + GlanceFormat.textOr(chargingState)
            + "  " + GlanceFormat.lockText(locked);
        _ageLine = GlanceFormat.ageText(age, Time.now().value());
    }

    // Bounded by the glance's own small dc (WatchUi.GlanceView's own
    // contract), so this stays to two short lines of Graphics.FONT_XTINY:
    // no attempt at the full top-strip layout ControlsView draws. US-059
    // adds one small icon (StateIcons.mc, (:glance)-annotated like Cache.mc)
    // to the left of the summary line.
    // Two lines: what this is, then what the car is doing.
    //
    // The name earns its line. A glance sits in a carousel among a dozen
    // others, and "72%  CHARGING  LOCKED" on its own does not say whose
    // numbers those are. Below it the state, with its age, or an invitation
    // when nothing has been fetched yet (US-034: never a blank glance).
    //
    // Both lines go through GlanceFormat.truncated(). The old code drew
    // straight and let anything too long run off the right edge, which is
    // what an unrecognised state value from the API did.
    function onUpdate(dc as Dc) as Void {
        var midY = dc.getHeight() / 2;
        var left = 18;
        var maxWidth = dc.getWidth() - left - 4;
        var measure = (new GlanceMetrics(dc)).method(:width);

        // Name on top, at the margin. No icon here: a lock symbol next to the
        // app's name says nothing about the app, and with no data cached it
        // would show the "unknown" glyph as though that were a reading.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, midY - 10, Graphics.FONT_XTINY,
            GlanceFormat.truncated(APP_NAME, dc.getWidth() - 12, measure),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // The lock icon belongs on the state line, where it is one of the
        // readings (US-059: never colour or words alone).
        if (_hasData) {
            StateIcons.draw(dc, _lockIcon, 8, midY + 10, 7, Graphics.COLOR_WHITE);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, midY + 10, Graphics.FONT_XTINY,
                GlanceFormat.truncated(_summaryLine + "  " + _ageLine, maxWidth, measure),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, midY + 10, Graphics.FONT_XTINY,
                GlanceFormat.truncated(INVITATION, dc.getWidth() - 12, measure),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private const APP_NAME as String = "Vozidlo";
    private const INVITATION as String = "Open for your car";

}

// Wraps a Dc so its text measurement can be passed as a Method, which is what
// lets GlanceFormat.truncated() be tested with arithmetic instead of graphics.
// (:glance) because the glance binary only contains annotated code: an
// unannotated symbol is absent, not merely discouraged, and calling it crashes.
(:glance)
class GlanceMetrics {
    private var _dc as Dc;

    function initialize(dc as Dc) {
        _dc = dc;
    }

    function width(s as String) as Number {
        return _dc.getTextWidthInPixels(s, Graphics.FONT_XTINY);
    }
}
