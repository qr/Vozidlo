import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Unit tests for NightMenuFocus (ui/NightMenu.mc): which rows of a list are
// drawn, frame by frame. A frame is played the way the CustomMenu draws one:
// every row's draw() in some order, each row knowing only its own focus
// state (CustomMenuItem.isFocused()). What a row is told about any other row
// is exactly what went wrong in 1.1.2's first build: its first frames asked
// every row for isFocused() and left the rows on screen blank.
module NightMenuFocusTests {

    // One frame: rows drawn in `order`, row `focused` reporting focus (-1:
    // none does). Returns [drawn per row, whether a redraw was asked].
    function frame(f as NightMenuFocus, count as Number, focused as Number,
                   order as Array<Number>) as [Array<Boolean>, Boolean] {
        var shown = [] as Array<Boolean>;
        for (var i = 0; i < count; i += 1) {
            shown.add(false);
        }
        var redraw = false;
        for (var k = 0; k < order.size(); k += 1) {
            var index = order[k];
            var isFocused = index == focused;
            if (f.drawn(index, isFocused)) {
                redraw = true;
            }
            shown[index] = f.shows(index, isFocused);
        }
        return [shown, redraw];
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

    // True when exactly the rows in `want` are drawn; logs the difference.
    function drawnAre(logger as Logger, label as String, shown as Array<Boolean>, want as Array<Number>) as Boolean {
        var ok = true;
        var got = "";
        for (var i = 0; i < shown.size(); i += 1) {
            if (shown[i]) {
                got += i.toString() + " ";
            }
            if (shown[i] != (want.indexOf(i) >= 0)) {
                ok = false;
            }
        }
        if (!ok) {
            logger.error(label + ": drawn rows " + got + "expected " + want.toString());
        }
        return ok;
    }

    // The bug: a menu opened on row 3 drew nothing until a later redraw.
    // The very first frame must already show rows 2, 3 and 4.
    (:test)
    function openingFrameShowsTheFocusAndItsNeighbours(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        var r = frame(f, 6, 3, up(6));
        if (!drawnAre(logger, "first frame", r[0], [2, 3, 4])) {
            return false;
        }
        if (r[1]) {
            logger.error("nothing moved, so no extra frame is needed");
            return false;
        }
        return true;
    }

    // The opening frame must not depend on what rows report about focus:
    // even when no row reports it yet, the menu was opened on row 3.
    (:test)
    function openingFrameNeedsNoRowToReportFocus(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        var r = frame(f, 6, -1, up(6));
        return drawnAre(logger, "no row focused yet", r[0], [2, 3, 4]);
    }

    // Garmin does not say in which order rows are drawn.
    (:test)
    function openingFrameIsRightInAnyDrawOrder(logger as Logger) as Boolean {
        var orders = [up(6), down(6), [3, 0, 1, 2, 4, 5], [0, 1, 2, 4, 5, 3]] as Array<Array<Number> >;
        for (var k = 0; k < orders.size(); k += 1) {
            var f = newFocus(3, 6);
            var r = frame(f, 6, 3, orders[k]);
            if (!drawnAre(logger, "order " + orders[k].toString(), r[0], [2, 3, 4])) {
                return false;
            }
        }
        return true;
    }

    // Should the platform report a stale focus for a frame (row 0 before it
    // applies the menu's :focus), the rows come right one frame after the
    // true focus is reported, and each change asks for that frame.
    (:test)
    function aStaleFocusReportSettlesInOneMoreFrame(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        var r = frame(f, 6, 0, up(6));
        if (!r[1]) {
            logger.error("a moved focus must ask for another frame");
            return false;
        }
        r = frame(f, 6, 3, up(6));
        if (!r[1]) {
            logger.error("moving back to row 3 must ask for another frame");
            return false;
        }
        r = frame(f, 6, 3, up(6));
        if (r[1]) {
            logger.error("a settled frame must not ask for more");
            return false;
        }
        return drawnAre(logger, "settled", r[0], [2, 3, 4]);
    }

    // DOWN: row 5 comes in, row 2 goes. The first frame after the move may
    // still lag behind for rows drawn before the new focus, so it asks for
    // one more; that one is exact.
    (:test)
    function scrollDownMovesTheWindow(logger as Logger) as Boolean {
        var orders = [up(6), down(6)] as Array<Array<Number> >;
        for (var k = 0; k < orders.size(); k += 1) {
            var f = newFocus(3, 6);
            frame(f, 6, 3, orders[k]);
            var r = frame(f, 6, 4, orders[k]);
            if (!r[1]) {
                logger.error("DOWN must ask for another frame");
                return false;
            }
            r = frame(f, 6, 4, orders[k]);
            if (!drawnAre(logger, "after DOWN, order " + orders[k].toString(), r[0], [3, 4, 5]) || r[1]) {
                return false;
            }
        }
        return true;
    }

    // UP with rows drawn top to bottom: row 1 is drawn before row 2 reports
    // the focus, so it is blank in that frame; the extra frame shows it.
    (:test)
    function scrollUpShowsTheNewRowInTheExtraFrame(logger as Logger) as Boolean {
        var f = newFocus(3, 6);
        frame(f, 6, 3, up(6));
        var r = frame(f, 6, 2, up(6));
        if (!r[1]) {
            logger.error("UP must ask for another frame");
            return false;
        }
        r = frame(f, 6, 2, up(6));
        return drawnAre(logger, "after UP", r[0], [1, 2, 3]);
    }

    // Home wraps at both ends; the title (the hero) belongs to row 0.
    (:test)
    function wrappingMovesTheWindowAndTheTitle(logger as Logger) as Boolean {
        var f = newFocus(5, 6);
        frame(f, 6, 5, up(6));
        if (f.titleShown()) {
            logger.error("no title on the last row");
            return false;
        }
        frame(f, 6, 0, up(6));
        var r = frame(f, 6, 0, up(6));
        if (!drawnAre(logger, "wrapped to the first row", r[0], [0, 1]) || !f.titleShown()) {
            logger.error("the title must show again on row 0");
            return false;
        }
        frame(f, 6, 5, up(6));
        r = frame(f, 6, 5, up(6));
        if (!drawnAre(logger, "wrapped to the last row", r[0], [4, 5]) || f.titleShown()) {
            return false;
        }
        return true;
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
    // as the platform does, rather than leaving every row blank.
    (:test)
    function anOutOfRangeFocusIsClamped(logger as Logger) as Boolean {
        var f = newFocus(9, 4);
        if (f.focus() != 3) {
            logger.error("focus 9 in 4 rows should be row 3, got " + f.focus().toString());
            return false;
        }
        if (!drawnAre(logger, "focus past the end", frame(f, 4, -1, up(4))[0], [2, 3])) {
            return false;
        }
        var g = newFocus(-1, 4);
        return drawnAre(logger, "negative focus", frame(g, 4, -1, up(4))[0], [0, 1]);
    }

    // HomeMenu rebuilds its rows and calls setFocus(): the window follows.
    (:test)
    function setMovesTheWindow(logger as Logger) as Boolean {
        var f = newFocus(4, 6);
        f.set(1);
        return drawnAre(logger, "after set(1)", frame(f, 6, -1, up(6))[0], [0, 1, 2]);
    }

    // The focused row is drawn whatever was tracked before.
    (:test)
    function theFocusedRowIsAlwaysDrawn(logger as Logger) as Boolean {
        var f = newFocus(0, 6);
        if (!f.shows(5, true)) {
            logger.error("a row reporting focus must be drawn");
            return false;
        }
        return true;
    }

    // A one- or two-row list shows all its rows.
    (:test)
    function shortListsShowEveryRow(logger as Logger) as Boolean {
        var one = newFocus(0, 1);
        if (!drawnAre(logger, "one row", frame(one, 1, 0, up(1))[0], [0])) {
            return false;
        }
        var two = newFocus(1, 2);
        return drawnAre(logger, "two rows", frame(two, 2, 1, up(2))[0], [0, 1]);
    }

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

    // Home is the first view the app shows.
    (:test)
    function theHomeMenuCanBeBuilt(logger as Logger) as Boolean {
        var home = new HomeMenu();
        if (home.getItem(0) == null) {
            logger.error("home must have at least one row (Settings)");
            return false;
        }
        return true;
    }

}
