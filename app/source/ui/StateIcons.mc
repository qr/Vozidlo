import Toybox.Graphics;
import Toybox.Lang;

// Task 11 (US-059/US-060): ONE icon per state. Locked, unlocked, open,
// charging, plugged in, climate active, unknown: used identically on the
// control tiles' top strip (ControlsView), the detailed status screen
// (StatusView) and the glance (GlanceView). Complications cannot reuse this
// module directly: Complications.Data (the dictionary updateComplication()
// accepts) has no `:icon` key. Complications.html documents `:shortLabel`,
// `:value`, `:unit`, `:ranges` only, so a complication's icon is fixed at
// publish time in resources/complications/complications.xml and can never
// change per-state. The four complication SVGs are instead hand-drawn to
// match this same bold, single-colour visual language (see that directory's
// own files): a static, generic glyph per complication TYPE is the most
// the platform allows; the exact state still reaches the user through the
// complication's :value text.
//
// Deliberately plain Graphics primitives (setPenWidth/drawLine/drawCircle/
// fillPolygon/fillRoundedRectangle), never a bitmap resource: no resource to
// load in onLayout()/onShow() (see docs/best-practices, "Never load
// resources inside onUpdate()"), and: critically for GlanceView, whose
// arena is only 65,536 bytes: a handful of draw calls costs far less than
// even one more scoped bitmap resource. Every icon is a bold, closed
// silhouette (no gradients, no thin single-pixel strokes, no fine detail)
// so it survives the 64-colour memory-in-pixel panel and, per the
// monochrome-test audit (this task's final report), stays identifiable by
// SHAPE ALONE with every colour stripped out, see MonochromeTest.mc.
//
// (:glance), because ui/GlanceView.mc's onUpdate() draws the lock icon
// from here. Without the annotation this module is absent from the glance
// binary and that call crashes at runtime: a suppressed type-check
// warning is not a substitute, see GlanceView.mc's header for how that was
// found. The module is a pure drawing helper with no state and no
// Toybox.Communications call, so it costs the glance arena little.
(:glance)
module StateIcons {

    const LOCKED as Symbol = :locked;
    const UNLOCKED as Symbol = :unlocked;
    const OPEN as Symbol = :open;
    const CHARGING as Symbol = :charging;
    const PLUGGED_IN as Symbol = :pluggedIn;
    const CLIMATE_ACTIVE as Symbol = :climateActive;
    const UNKNOWN as Symbol = :unknown;

    // ------------------------------------------------------- state mapping
    //
    // Pure and side-effect-free, exactly like ui/ControlsView.mc's own
    // ControlTiles module: testable without a Dc or a live View. Every
    // raw value comes straight off the API's documented enums (see
    // model/VehicleState.mc and ui/ChargingLogic.mc for the same strings
    // used elsewhere); an unrecognised value always falls through rather
    // than crashing, matching this app's "clients must tolerate values they
    // do not recognize" rule everywhere else.

    // status.doorsLocked -> one of the four door/lock states. Always
    // returns a real icon (never null): lock status is the one indicator
    // this app shows unconditionally, so "no data yet" becomes UNKNOWN
    // rather than an empty slot: US-059's own "given an unknown state,
    // then it has its own icon rather than borrowing another."
    function forLockStatus(raw as String?) as Symbol {
        if (raw == null) {
            return UNKNOWN;
        }
        if (raw.equals("YES")) {
            return LOCKED;
        }
        if (raw.equals("NO")) {
            return UNLOCKED;
        }
        if (raw.equals("OPENED")) {
            return OPEN;
        }
        if (raw.equals("TRUNK_OPENED")) {
            return OPEN;
        }
        return UNKNOWN;
    }

    // charging.state -> CHARGING or PLUGGED_IN, or null when the state
    // doesn't warrant either icon (CONNECT_CABLE/DISCHARGING/anything else
    // unrecognised): a blank icon slot here is a deliberate design choice,
    // not the same thing as UNKNOWN, which this module reserves for "no
    // data at all" (see forLockStatus above and StatusView's own
    // KIND_UNKNOWN convention that this mirrors).
    function forChargingStatus(raw as String?) as Symbol? {
        if (raw == null) {
            return null;
        }
        if (raw.equals("CHARGING")) {
            return CHARGING;
        }
        if (raw.equals("READY_FOR_CHARGING")) {
            return PLUGGED_IN;
        }
        if (raw.equals("CONSERVING")) {
            return PLUGGED_IN;
        }
        if (raw.equals("CHARGING_INTERRUPTED")) {
            return PLUGGED_IN;
        }
        return null;
    }

    // airConditioning.state -> CLIMATE_ACTIVE for any of the four
    // documented "running" values, or null for OFF/unrecognised: same
    // "blank slot, not UNKNOWN" reasoning as forChargingStatus above.
    function forClimateStatus(raw as String?) as Symbol? {
        if (raw == null) {
            return null;
        }
        if (raw.equals("HEATING")) {
            return CLIMATE_ACTIVE;
        }
        if (raw.equals("COOLING")) {
            return CLIMATE_ACTIVE;
        }
        if (raw.equals("VENTILATION")) {
            return CLIMATE_ACTIVE;
        }
        if (raw.equals("HEATING_AUXILIARY")) {
            return CLIMATE_ACTIVE;
        }
        return null;
    }

    // ------------------------------------------------------------ drawing
    //
    // `cx`/`cy` is the icon's centre; `r` is its half-size (roughly a
    // bounding radius) so the same functions scale from a ~6px glance glyph
    // to a ~16px status-page glyph without any caller needing to know the
    // per-icon geometry. Every icon draws in `color` alone: never reads
    // the destination background, so these are safe on the tiles' varying
    // backgrounds (dark grey / blue / green) as well as StatusView's black
    // canvas and the glance's own background.

    function draw(dc as Dc, state as Symbol, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        if (state == LOCKED) {
            _drawLocked(dc, cx, cy, r, color);
            return;
        }
        if (state == UNLOCKED) {
            _drawUnlocked(dc, cx, cy, r, color);
            return;
        }
        if (state == OPEN) {
            _drawOpen(dc, cx, cy, r, color);
            return;
        }
        if (state == CHARGING) {
            _drawCharging(dc, cx, cy, r, color);
            return;
        }
        if (state == PLUGGED_IN) {
            _drawPluggedIn(dc, cx, cy, r, color);
            return;
        }
        if (state == CLIMATE_ACTIVE) {
            _drawClimateActive(dc, cx, cy, r, color);
            return;
        }
        _drawUnknown(dc, cx, cy, r, color);
    }

    // Closed padlock: a symmetric "loop" (stroked pill) straddling the top
    // of a solid body, drawn BEFORE the body so the body's fill covers the
    // loop's lower half: the loop reads as emerging from the box, exactly
    // the classic padlock silhouette. Symmetric and centred: this is the
    // shape UNLOCKED below deliberately breaks.
    function _drawLocked(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        var bodyW = (r * 1.5).toNumber();
        var bodyH = (r * 1.05).toNumber();
        var bodyX = (cx - (bodyW / 2)).toNumber();
        var bodyY = (cy - (r * 0.1)).toNumber();

        var shackleW = (r * 0.9).toNumber();
        var shackleH = (r * 1.05).toNumber();
        var shackleX = (cx - (shackleW / 2)).toNumber();
        var shackleY = (cy - (r * 1.05)).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_strokeWidth(r));
        dc.drawRoundedRectangle(shackleX, shackleY, shackleW, shackleH, (shackleW / 2).toNumber());
        dc.fillRoundedRectangle(bodyX, bodyY, bodyW, bodyH, (r * 0.25).toNumber());
    }

    // Open padlock: identical body, but the loop is shifted up and to the
    // LEFT so only its lower-left corner still overlaps the body: an
    // asymmetric silhouette, unmistakably different from LOCKED's centred
    // loop even with every colour removed (the monochrome test).
    function _drawUnlocked(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        var bodyW = (r * 1.5).toNumber();
        var bodyH = (r * 1.05).toNumber();
        var bodyX = (cx - (bodyW / 2)).toNumber();
        var bodyY = (cy - (r * 0.1)).toNumber();

        var shackleW = (r * 0.9).toNumber();
        var shackleH = (r * 1.05).toNumber();
        var shackleX = (bodyX - (r * 0.05)).toNumber();
        var shackleY = (cy - (r * 1.35)).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_strokeWidth(r));
        dc.drawRoundedRectangle(shackleX, shackleY, shackleW, shackleH, (shackleW / 2).toNumber());
        dc.fillRoundedRectangle(bodyX, bodyY, bodyW, bodyH, (r * 0.25).toNumber());
    }

    // Door/trunk open: a hinge pole with a triangular "flag" swung out to
    // the right: an elongated, diagonal silhouette with nothing in common
    // with the compact padlock/plug/bolt shapes, so it cannot be confused
    // with any of them by outline alone.
    function _drawOpen(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_strokeWidth(r));
        var poleX = (cx - (r * 0.5)).toNumber();
        dc.drawLine(poleX, (cy - r).toNumber(), poleX, (cy + r).toNumber());
        dc.fillPolygon([
            [poleX, (cy - (r * 0.6)).toNumber()] as Graphics.Point2D,
            [poleX, (cy - (r * 0.05)).toNumber()] as Graphics.Point2D,
            [(cx + (r * 0.7)).toNumber(), (cy - (r * 0.35)).toNumber()] as Graphics.Point2D
        ] as Array<Graphics.Point2D>);
    }

    // Lightning bolt: the same zigzag as
    // resources/complications/charging_icon.svg, re-derived as offsets from
    // the icon's own centre so it scales to any `r`.
    function _drawCharging(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        var s = r / 7.0;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [(cx + (1 * s)).toNumber(), (cy + (-7 * s)).toNumber()] as Graphics.Point2D,
            [(cx + (-5 * s)).toNumber(), (cy + (1 * s)).toNumber()] as Graphics.Point2D,
            [(cx + (-0.5 * s)).toNumber(), (cy + (1 * s)).toNumber()] as Graphics.Point2D,
            [(cx + (-1.5 * s)).toNumber(), (cy + (7 * s)).toNumber()] as Graphics.Point2D,
            [(cx + (5 * s)).toNumber(), (cy + (-1.5 * s)).toNumber()] as Graphics.Point2D,
            [(cx + (0.5 * s)).toNumber(), (cy + (-1.5 * s)).toNumber()] as Graphics.Point2D
        ] as Array<Graphics.Point2D>);
    }

    // Electrical plug: a blocky body with two short prongs. Solid,
    // rectilinear, nothing like the bolt's zigzag or the padlocks' pill
    // shapes.
    function _drawPluggedIn(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var bodyW = (r * 1.0).toNumber();
        var bodyH = (r * 0.9).toNumber();
        dc.fillRoundedRectangle((cx - (r * 0.5)).toNumber(), (cy - (r * 0.1)).toNumber(), bodyW, bodyH, (r * 0.2).toNumber());
        var prongW = (r * 0.18).toNumber();
        var prongH = (r * 0.6).toNumber();
        dc.fillRoundedRectangle((cx - (r * 0.32)).toNumber(), (cy - (r * 0.7)).toNumber(), prongW, prongH, (r * 0.06).toNumber());
        dc.fillRoundedRectangle((cx + (r * 0.12)).toNumber(), (cy - (r * 0.7)).toNumber(), prongW, prongH, (r * 0.06).toNumber());
    }

    // Climate active: a bold 8-point asterisk (four lines through the
    // centre): spokes radiating to the full bounding box, the only icon in
    // this set with that silhouette, standing in for a snowflake/fan
    // without the fine detail a real one would need at this size.
    function _drawClimateActive(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_strokeWidth(r));
        dc.drawLine((cx - r).toNumber(), cy, (cx + r).toNumber(), cy);
        dc.drawLine(cx, (cy - r).toNumber(), cx, (cy + r).toNumber());
        dc.drawLine((cx - (r * 0.7)).toNumber(), (cy - (r * 0.7)).toNumber(), (cx + (r * 0.7)).toNumber(), (cy + (r * 0.7)).toNumber());
        dc.drawLine((cx - (r * 0.7)).toNumber(), (cy + (r * 0.7)).toNumber(), (cx + (r * 0.7)).toNumber(), (cy - (r * 0.7)).toNumber());
    }

    // Unknown: a plain ring with a horizontal dash through the middle.
    // echoing the EM_DASH already used everywhere in this app's text for
    // "no data" (see ControlsView/StatusView/GlanceView's own EM_DASH
    // constants), so the one glyph with no state of its own to show still
    // reads as "nothing here yet" rather than a blank.
    function _drawUnknown(dc as Dc, cx as Number, cy as Number, r as Number, color as Graphics.ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_strokeWidth(r));
        dc.drawCircle(cx, cy, r);
        dc.drawLine((cx - (r * 0.5)).toNumber(), cy, (cx + (r * 0.5)).toNumber(), cy);
    }

    // A thick-enough stroke to survive the 64-colour memory-in-pixel panel
    // at every size this app actually uses (see the class comment on "bold
    // shapes, no fine detail"), never thinner than 2px.
    function _strokeWidth(r as Number) as Number {
        var w = (r / 4).toNumber();
        if (w < 2) {
            return 2;
        }
        return w;
    }

}
