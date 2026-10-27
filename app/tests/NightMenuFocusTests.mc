import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Unit tests for NightMenuFocus, the list mask and the row layout cache
// (ui/NightMenu.mc). Every row of a list is drawn; on the button watches
// the mask decides what shows, by where a row is, and only its top band
// follows the focus. A frame is played the way the CustomMenu draws one:
// every row's draw() in some order, each row knowing only its own focus
// state (CustomMenuItem.isFocused()), then drawForeground() (endFrame). What
// a row is told about any other row is exactly what went wrong in 1.1.2's
// first build: its first frames asked every row for isFocused() and left
// the rows on screen blank.
//
// Up to 1.3.0 these tests checked which rows were drawn (the focus and one
// either side). That rule left rows blank while Garmin's animation still
// had them on screen; the scroll tests below play the frames in between.
module NightMenuFocusTests {

    // One frame: rows drawn in `order`, the rows in `focused` reporting
    // focus, then the foreground. Returns [the focus the mask used, whether
    // a redraw was asked].
    function frameOf(f as NightMenuFocus, order as Array<Number>, focused as Array<Number>) as [Number, Boolean] {
        var redraw = false;
        for (var k = 0; k < order.size(); k += 1) {
            var index = order[k];
            if (f.drawn(index, focused.indexOf(index) >= 0)) {
                if (redraw) {
                    return [-1, true];
                }
                redraw = true;
            }
        }
        var focus = f.focus();
        f.endFrame();
        return [focus, redraw];
    }

    // frameOf() with one row (or none, -1) reporting focus.
    function frame(f as NightMenuFocus, focused as Number, order as Array<Number>) as [Number, Boolean] {
        return frameOf(f, order, focused >= 0 ? [focused] as Array<Number> : [] as Array<Number>);
    }

    function up(count as Number) as Array<Number> {
        var a = [] as Array<Number>;
        for (var i = 0; i < count; i += 1) {
            a.add(i);
        }
        return a;
    }

    function down(count as Number) as Array<Number> {
        var a = [] as Array<Number>;
        for (var i = count - 1; i >= 0; i -= 1) {
            a.add(i);
        }
        return a;
    }

    function newFocus(focus as Number, count as Number) as NightMenuFocus {
        var f = new NightMenuFocus(focus);
        f.setCount(count);
        return f;
    }

    // True when the frame used focus `want` and asked for a redraw exactly
    // when `redraw`; logs the difference.
    function frameIs(logger as Logger, label as String, r as [Number, Boolean], want as Number, redraw as Boolean) as Boolean {
        if (r[0] != want || r[1] != redraw) {
            logger.error(label + ": focus " + r[0].toString() + (r[1] ? " with" : " without") + " a redraw, expected "
                + want.toString() + (redraw ? " with" : " without") + " one");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ focus

    // The bug of 1.1.3: a menu opened on row 3 drew nothing until a later
    // redraw. Rows draw whatever the focus now; the first frame must
    // already mask for row 3 and ask for nothing more.
    (:test)
    function openingFrameKeepsTheOpeningFocus(logger as Logger) as Boolean {
        return frameIs(logger, "first frame", frame(newFocus(3, 6), 3, up(6)), 3, false);
    }

    // The opening frame must not depend on what rows report about focus:
    // even when no row reports it yet, the menu was opened on row 3.
    (:test)
    function openingFrameNeedsNoRowToReportFocus(logger as Logger) as Boolean {
        return frameIs(logger, "no row focused yet", frame(newFocus(3, 6), -1, up(6)), 3, false);
    }

    // Garmin does not say in which order rows are drawn.
    (:test)
    function openingFrameIsRightInAnyDrawOrder(logger as Logger) as Boolean {
        var orders = [up(6), down(6), [3, 0, 1, 2, 4, 5], [0, 1, 2, 4, 5, 3]] as Array<Array<Number> >;
        for (var k = 0; k < orders.size(); k += 1) {
            if (!frameIs(logger, "order " + orders[k].toString(), frame(newFocus(3, 6), 3, orders[k]), 3, false)) {
                return false;
            }
        }
        return true;
    }

    // Should the platform report a stale focus for a frame (row 0 before it
    // applies the menu's :focus), the mask follows it in that frame and
    // comes right in the frame the true focus is reported. Both moves show
    // or hide the title, so each asks for its one safety-net frame.
    (:test)
    function aStaleFocusReportSettlesInOneMoreFrame(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        return frameIs(logger, "stale row 0", frame(f, 0, up(6)), 0, true)
            && frameIs(logger, "back to row 3", frame(f, 3, up(6)), 3, true)
            && frameIs(logger, "settled", frame(f, 3, up(6)), 3, false);
    }

    // DOWN and UP move the focus in the frame the new row reports it, in
    // either draw order, and ask for no extra frame: the mask reads the
    // focus after the rows. Up to 1.3.0 every move asked for one.
    (:test)
    function aStepMovesTheFocusInItsOwnFrame(logger as Logger) as Boolean {
        var orders = [up(6), down(6)] as Array<Array<Number> >;
        for (var k = 0; k < orders.size(); k += 1) {
            var f = newFocus(3, 6);
            var o = orders[k].toString();
            if (!frameIs(logger, "DOWN, order " + o, frame(f, 4, orders[k]), 4, false)
                || !frameIs(logger, "UP, order " + o, frame(f, 3, orders[k]), 3, false)
                || !frameIs(logger, "UP again, order " + o, frame(f, 2, orders[k]), 2, false)) {
                return false;
            }
        }
        return true;
    }

    // Two rows reporting focus in one frame (the Venu 3, and the old and
    // new row after setFocus): the first one drawn decides, the second is
    // ignored, frame after frame, and a frame asks for at most one redraw.
    // Up to 1.3.0 the focus swung between the two and every frame asked for
    // another.
    (:test)
    function aSecondFocusedRowInAFrameIsIgnored(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        for (var k = 0; k < 3; k += 1) {
            if (!frameIs(logger, "rows 4 and 5, frame " + k.toString(), frameOf(f, up(6), [4, 5] as Array<Number>), 4, false)) {
                return false;
            }
        }
        for (var k = 0; k < 3; k += 1) {
            if (!frameIs(logger, "drawn bottom up, frame " + k.toString(), frameOf(f, down(6), [4, 5] as Array<Number>), 5, false)) {
                return false;
            }
        }
        var g = newFocus(2, 6);
        return frameIs(logger, "rows 0 and 1, title appears", frameOf(g, up(6), [0, 1] as Array<Number>), 0, true);
    }

    // A frame whose foreground never comes still lets the focus move once
    // the row that moved it draws again.
    (:test)
    function aFrameWithoutForegroundStillEnds(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        f.drawn(4, true);
        f.drawn(5, true);
        if (f.focus() != 4) {
            logger.error("in one frame the first focused row wins, got " + f.focus().toString());
            return false;
        }
        f.drawn(4, false);
        f.drawn(5, true);
        if (f.focus() != 5) {
            logger.error("row 4 drawing again starts a new frame, so row 5 moves the focus; got " + f.focus().toString());
            return false;
        }
        return true;
    }

    // Home wraps at both ends; the title (the hero) belongs to row 0, and
    // showing or hiding it is the one move that asks for a frame.
    (:test)
    function wrappingMovesTheFocusAndTheTitle(logger as Logger) as Boolean {
        var f = newFocus(5, 6);
        frame(f, 5, up(6));
        if (f.titleShown()) {
            logger.error("no title on the last row");
            return false;
        }
        if (!frameIs(logger, "wrapped to the first row", frame(f, 0, up(6)), 0, true) || !f.titleShown()) {
            logger.error("the title must show again on row 0");
            return false;
        }
        return frameIs(logger, "wrapped to the last row", frame(f, 5, up(6)), 5, true) && !f.titleShown();
    }

    // The title shows on row 0 only, from the first frame on.
    (:test)
    function titleShowsOnTheFirstRowOnly(logger as Logger) as Boolean {
        if (!newFocus(0, 6).titleShown()) {
            logger.error("title at focus 0");
            return false;
        }
        if (newFocus(1, 6).titleShown()) {
            logger.error("no title at focus 1: only its bottom would show, cut by the edge");
            return false;
        }
        return true;
    }

    // A :focus past the end (or negative) lands on the last (or first) row,
    // as the platform does.
    (:test)
    function anOutOfRangeFocusIsClamped(logger as Logger) as Boolean {
        var f = newFocus(9, 4);
        if (f.focus() != 3) {
            logger.error("focus 9 in 4 rows should be row 3, got " + f.focus().toString());
            return false;
        }
        return frameIs(logger, "focus past the end", frame(f, -1, up(4)), 3, false)
            && frameIs(logger, "negative focus", frame(newFocus(-1, 4), -1, up(4)), 0, false);
    }

    // HomeMenu rebuilds its rows and calls setFocus(): the mask follows.
    (:test)
    function setMovesTheFocus(logger as Logger) as Boolean {
        var f = newFocus(4, 6);
        f.set(1);
        return frameIs(logger, "after set(1)", frame(f, -1, up(6)), 1, false);
    }

    // ------------------------------------------------------------ scrolling

    // Garmin does not say when isFocused() changes during a scroll
    // animation, so each step is played three ways: the new row reports
    // focus from the first moved frame on (:start), only in the last one
    // (:end), or no row reports it while the list moves (:drag, touch).
    const SCENARIOS = [:start, :end, :drag] as Array<Symbol>;
    // How far the rows have moved, in px of a 65 px row (fēnix 7 Pro).
    const SHIFTS = [0, 8, 16, 33, 49, 57, 65] as Array<Number>;

    // The row reporting focus at `shift` px into a step from row `from` to
    // `to`, or -1 when none does.
    function reporting(scenario as Symbol, from as Number, to as Number, shift as Number, rowH as Number) as Number {
        if (shift == 0) {
            return from;
        }
        if (shift >= rowH) {
            return to;
        }
        if (scenario == :start) {
            return to;
        }
        return scenario == :end ? from : -1;
    }

    // Pixels of [top, bottom) that are on a screen h high and outside the
    // mask bands (NightMenuLayout.maskBands).
    function shown(top as Number, bottom as Number, h as Number, bands as [Number, Number]) as Number {
        var a = top > bands[0] ? top : bands[0];
        var b = bottom < bands[1] ? bottom : bands[1];
        if (a < 0) {
            a = 0;
        }
        if (b > h) {
            b = h;
        }
        return b > a ? b - a : 0;
    }

    // Pixels of [top, bottom) within a row and a half of the centre, a
    // pixel counting when any of it is: the part of the screen a list
    // shows on the button watches.
    function inWindow(top as Number, bottom as Number, g as Geo.Display) as Number {
        var half = (3 * g.rowH + 1) / 2;
        return shown(top, bottom, g.h, [g.cy - half, g.cy + half]);
    }

    function nameOf(scenario as Symbol) as String {
        if (scenario == :start) {
            return "start";
        }
        return scenario == :end ? "end" : "drag";
    }

    // Plays one step on a list of `count` rows and checks every frame:
    // every part of a row within a row and a half of the centre shows
    // (nothing on screen there is blank), and nothing beyond it does, the
    // title on row 0 aside. Up to 1.3.0, in :start, the row leaving was
    // blank from the first frame while still half in view; in :end the row
    // coming in slid in blank.
    function stepShowsEveryRowInView(logger as Logger, g as Geo.Display, count as Number, from as Number, to as Number) as Boolean {
        var rowH = g.rowH;
        var dir = to > from ? 1 : -1;
        for (var s = 0; s < SCENARIOS.size(); s += 1) {
            var f = newFocus(from, count);
            for (var k = 0; k < SHIFTS.size(); k += 1) {
                var shift = SHIFTS[k] * rowH / 65;
                var r = frame(f, reporting(SCENARIOS[s], from, to, shift, rowH), up(count));
                var bands = NightMenuLayout.maskBands(g.h, rowH, r[0]);
                var label = nameOf(SCENARIOS[s]) + " " + from.toString() + "->" + to.toString() + " at " + shift.toString() + " px, row ";
                for (var i = 0; i < count; i += 1) {
                    var top = (g.h - rowH) / 2 + (i - from) * rowH - dir * shift;
                    var px = shown(top, top + rowH, g.h, bands);
                    var want = inWindow(top, top + rowH, g);
                    if (px < want) {
                        logger.error(label + i.toString() + ": " + px.toString() + " px shown, " + want.toString() + " in view");
                        return false;
                    }
                    if (px > want && !(r[0] == 0 && top < g.cy)) {
                        logger.error(label + i.toString() + ": " + (px - want).toString() + " px shown beyond the window");
                        return false;
                    }
                }
            }
        }
        return true;
    }

    // The temperature list (15 rows) on the fēnix 7 Pro, stepping down and
    // up from the middle and off the first row.
    (:test)
    function rowsSlideThroughTheMaskMidStep(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        return stepShowsEveryRowInView(logger, g, 15, 7, 8)
            && stepShowsEveryRowInView(logger, g, 15, 7, 6)
            && stepShowsEveryRowInView(logger, g, 15, 0, 1)
            && stepShowsEveryRowInView(logger, g, 15, 1, 0)
            && stepShowsEveryRowInView(logger, g, 15, 14, 13);
    }

    // The same steps on the other button-watch screens, rows of other sizes.
    (:test)
    function rowsSlideThroughTheMaskOnEveryButtonWatch(logger as Logger) as Boolean {
        var all = GeoTests.all();
        for (var i = 0; i < all.size(); i += 1) {
            var g = all[i] as Geo.Display;
            if (NightMenuLayout.masks(g.input)
                && (!stepShowsEveryRowInView(logger, g, 15, 7, 8) || !stepShowsEveryRowInView(logger, g, 15, 7, 6))) {
                logger.error("on the " + g.w.toString() + " px screen");
                return false;
            }
        }
        return true;
    }

    // Home from row 0 to row 1 and back: the hero (the title, heroBottom
    // high, row 0 right under it) stays in view until it has scrolled past
    // the window, and is gone once row 1 has settled, but for at most the
    // one pixel the mask's outward rounding leaves. Up to 1.3.0 it went blank
    // in the first frame with the new focus, about 85 of its 98 px still on
    // screen.
    (:test)
    function theHeroStaysInViewUntilItScrollsOut(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var rowH = g.rowH;
        for (var s = 0; s < SCENARIOS.size(); s += 1) {
            var f = newFocus(0, 6);
            for (var k = 0; k < SHIFTS.size(); k += 1) {
                var shift = SHIFTS[k];
                var r = frame(f, reporting(SCENARIOS[s], 0, 1, shift, rowH), up(6));
                var bottom = g.heroBottom - shift;
                var px = shown(bottom - g.heroBottom, bottom, g.h, NightMenuLayout.maskBands(g.h, rowH, r[0]));
                var label = nameOf(SCENARIOS[s]) + " down at " + shift.toString() + " px: hero ";
                if (shift < rowH && px == 0) {
                    logger.error(label + "blank while " + bottom.toString() + " px of it are on screen");
                    return false;
                }
                if (shift == rowH && px > 1) {
                    logger.error(label + "still shows " + px.toString() + " px once row 1 has settled");
                    return false;
                }
            }
            // Back up: from the first frame with focus 0 the hero shows
            // all of it that is on screen.
            var r = frame(f, 0, up(6));
            var bottom = g.heroBottom - rowH + 16;
            var px = shown(bottom - g.heroBottom, bottom, g.h, NightMenuLayout.maskBands(g.h, rowH, r[0]));
            if (px != bottom) {
                logger.error(nameOf(SCENARIOS[s]) + " up: hero shows " + px.toString() + " of " + bottom.toString() + " px");
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------ layout cache

    // A row is laid out once per state and dc size.
    (:test)
    function aRowIsLaidOutOncePerState(logger as Logger) as Boolean {
        var c = new NightMenuRowCache();
        if (c.at(234, 65).plain() != null || c.focused() != null) {
            logger.error("a new row has no layout");
            return false;
        }
        c.setPlain(["Refresh", null, 80] as [String, String?, Number]);
        c.setFocused(["Refresh", null, Graphics.FONT_MEDIUM] as [String, String?, Graphics.FontType]);
        if (c.at(234, 65).plain() == null || c.focused() == null) {
            logger.error("the next frame in the same dc reuses both states");
            return false;
        }
        if (c.at(234, 80).plain() != null || c.focused() != null) {
            logger.error("a dc of another size lays the row out again");
            return false;
        }
        return true;
    }

    // setText, setSub and setChecked each clear the layout, both states.
    (:test)
    function changingARowClearsItsLayout(logger as Logger) as Boolean {
        var item = new NightMenuItem(:limit, "Set charge limit", "80%", :battery, null);
        var changes = ["text", "sub", "checked"] as Array<String>;
        for (var k = 0; k < changes.size(); k += 1) {
            var c = item.layout().at(234, 65);
            c.setPlain(["Set charge limit", "80%", 120] as [String, String?, Number]);
            c.setFocused(["Set charge limit", "80%", Graphics.FONT_SMALL] as [String, String?, Graphics.FontType]);
            if (changes[k].equals("text")) {
                item.setText("Set charge limit again");
            } else if (changes[k].equals("sub")) {
                item.setSub("90%");
            } else {
                item.setChecked(true);
            }
            if (item.layout().at(234, 65).plain() != null || item.layout().focused() != null) {
                logger.error("set" + changes[k] + " must clear the row's layout");
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------ debug trace

    // The debug build's menu trace (MenuTrace): one line per frame, newest
    // first, with the rows drawn, the rows reporting focus and the focus
    // the mask used; rows after the last frame end say so.
    (:test)
    function theDebugTraceShowsOneLinePerFrame(logger as Logger) as Boolean {
        MenuTrace.clear();
        MenuTrace.shown(15);
        MenuTrace.row(6, false, 65);
        MenuTrace.row(7, true, 65);
        MenuTrace.row(8, true, 65);
        MenuTrace.frame(7);
        MenuTrace.row(7, false, 65);
        var lines = MenuTrace.lines();
        MenuTrace.clear();
        var want = [" 7-7 f- no end", " 6-8 f7,8 m7", " list, 15 rows"] as Array<String>;
        if (lines.size() != want.size()) {
            logger.error("expected " + want.size().toString() + " lines, got " + lines.toString());
            return false;
        }
        for (var i = 0; i < want.size(); i += 1) {
            var line = lines[i];
            var tail = want[i];
            var end = line.length() >= tail.length() ? line.substring(line.length() - tail.length(), line.length()) : null;
            if (end == null || !end.equals(tail)) {
                logger.error("line " + i.toString() + " is \"" + line + "\", expected it to end in \"" + tail + "\"");
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------ building

    // Building the real menus, as the app does at launch. The platform's
    // CustomMenu constructor may call setFocus() for its :focus option, which
    // NightMenu overrides: everything that override touches must exist
    // before the constructor runs (1.1.3 crashed at launch on the watch).
    (:test)
    function aNightMenuCanBeBuiltWithAFocus(logger as Logger) as Boolean {
        var menu = new NightMenu("Charging", 2, null);
        menu.addItem(new NightMenuItem(:a, "A", null, null, null));
        menu.addItem(new NightMenuItem(:b, "B", "Sub", null, null));
        menu.addItem(new NightMenuItem(:c, "C", null, null, true));
        if (menu.focusState().focus() != 2) {
            logger.error("expected focus 2, got " + menu.focusState().focus().toString());
            return false;
        }
        menu.setFocus(0);
        if (menu.focusState().focus() != 0 || !menu.titleShown()) {
            logger.error("setFocus(0) must move the tracked focus to the first row");
            return false;
        }
        menu.deleteItem(0);
        menu.setFocus(5);
        if (menu.focusState().focus() != 1) {
            logger.error("after deleting a row, focus 5 must clamp to the last of 2 rows");
            return false;
        }
        return true;
    }

    // Home is the first view the app shows. The tests run a debug build, so
    // home ends with the menu trace row (MenuTrace); a release build has none.
    (:test)
    function theHomeMenuCanBeBuilt(logger as Logger) as Boolean {
        var home = new HomeMenu();
        if (home.getItem(0) == null) {
            logger.error("home must have at least one row (Settings)");
            return false;
        }
        var i = 0;
        while (home.getItem(i + 1) != null) {
            i += 1;
        }
        var last = home.getItem(i);
        if (last == null || last.getId() != MenuTrace.ROW) {
            logger.error("the debug build's home must end with the menu trace row");
            return false;
        }
        return true;
    }

}
