import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/ui/GridScroll.mc, the control grid's scrolling
// arithmetic.
//
// The bug these exist for: seven tiles need four rows, only three fit on a
// round 260x260 face, and the fourth row was drawn under the bezel. The
// "More" tile was cut in half on a real watch. The simulator showed it fine,
// which is why nothing caught it before someone wore the thing.
//
// Seven tiles in two columns is the real case throughout: four rows, a window
// of three.
module GridScrollTests {

    const COLUMNS = 2;
    const WINDOW = 3;

    (:test)
    function rowCountRoundsUp(logger as Logger) as Boolean {
        // Seven tiles in two columns is four rows, the last holding one tile.
        if (GridScroll.rowCount(7, COLUMNS) != 4) {
            logger.error("7 tiles in 2 columns should be 4 rows, got "
                         + GridScroll.rowCount(7, COLUMNS));
            return false;
        }
        if (GridScroll.rowCount(6, COLUMNS) != 3) {
            logger.error("6 tiles should be exactly 3 rows");
            return false;
        }
        if (GridScroll.rowCount(1, COLUMNS) != 1) {
            logger.error("1 tile should be 1 row");
            return false;
        }
        if (GridScroll.rowCount(0, COLUMNS) != 0) {
            logger.error("no tiles should be no rows");
            return false;
        }
        return true;
    }

    // A grid that already fits must never scroll. Six tiles are three rows,
    // exactly the window, so the offset stays 0 wherever the focus goes.
    (:test)
    function aGridThatFitsNeverScrolls(logger as Logger) as Boolean {
        var total = GridScroll.rowCount(6, COLUMNS);
        for (var row = 0; row < total; row += 1) {
            var offset = GridScroll.offsetFor(0, row, WINDOW, total);
            if (offset != 0) {
                logger.error("row " + row + " of a fitting grid scrolled to " + offset);
                return false;
            }
        }
        return true;
    }

    // Rows inside the window leave it alone. This is the common case: most
    // moves do not scroll at all.
    (:test)
    function aVisibleRowDoesNotMoveTheWindow(logger as Logger) as Boolean {
        var total = 4;
        for (var row = 0; row < WINDOW; row += 1) {
            if (GridScroll.offsetFor(0, row, WINDOW, total) != 0) {
                logger.error("row " + row + " is already visible at offset 0");
                return false;
            }
        }
        return true;
    }

    // The actual bug. Row 3 is the one holding "More"; reaching it must
    // scroll the window by exactly one row so the tile is whole.
    (:test)
    function reachingTheLastRowScrollsItIntoView(logger as Logger) as Boolean {
        var total = GridScroll.rowCount(7, COLUMNS);   // 4
        var offset = GridScroll.offsetFor(0, 3, WINDOW, total);
        if (offset != 1) {
            logger.error("focusing row 3 should scroll to offset 1, got " + offset);
            return false;
        }
        // And at that offset the row really is inside the window.
        if (3 < offset || 3 > offset + WINDOW - 1) {
            logger.error("row 3 still outside the window at offset " + offset);
            return false;
        }
        return true;
    }

    // Scrolling back up is symmetric, and by one row, not a jump to the top.
    (:test)
    function movingBackUpScrollsByOneRow(logger as Logger) as Boolean {
        var total = 4;
        var offset = GridScroll.offsetFor(1, 0, WINDOW, total);
        if (offset != 0) {
            logger.error("focusing row 0 from offset 1 should give 0, got " + offset);
            return false;
        }
        // Row 1 is visible at offset 1, so nothing should move.
        if (GridScroll.offsetFor(1, 1, WINDOW, total) != 1) {
            logger.error("row 1 is visible at offset 1 and should not scroll");
            return false;
        }
        return true;
    }

    // The window must never run off either end, leaving blank rows.
    (:test)
    function theWindowNeverScrollsPastTheEnds(logger as Logger) as Boolean {
        var total = 4;
        // Asking for a row beyond the end still clamps to the last window.
        var past = GridScroll.offsetFor(0, 99, WINDOW, total);
        if (past != total - WINDOW) {
            logger.error("expected clamp to " + (total - WINDOW) + ", got " + past);
            return false;
        }
        // A negative row cannot drag the window above zero.
        if (GridScroll.offsetFor(1, -5, WINDOW, total) != 0) {
            logger.error("a negative row must clamp to offset 0");
            return false;
        }
        // A window larger than the content pins the offset at zero rather
        // than going negative.
        if (GridScroll.offsetFor(0, 0, 10, 2) != 0) {
            logger.error("a window larger than the content must stay at 0");
            return false;
        }
        return true;
    }

    // Walking the whole grid top to bottom and back, the focused row is
    // inside the window at every step. This is the property that actually
    // matters; the cases above are the interesting individual points on it.
    (:test)
    function everyRowIsVisibleWhenFocusedWalkingBothWays(logger as Logger) as Boolean {
        var total = GridScroll.rowCount(7, COLUMNS);
        var offset = 0;
        for (var row = 0; row < total; row += 1) {
            offset = GridScroll.offsetFor(offset, row, WINDOW, total);
            if (row < offset || row > offset + WINDOW - 1) {
                logger.error("going down: row " + row + " not visible at offset " + offset);
                return false;
            }
        }
        for (var row = total - 1; row >= 0; row -= 1) {
            offset = GridScroll.offsetFor(offset, row, WINDOW, total);
            if (row < offset || row > offset + WINDOW - 1) {
                logger.error("going up: row " + row + " not visible at offset " + offset);
                return false;
            }
        }
        return true;
    }

    // The carets only appear when there is something to scroll to.
    (:test)
    function scrollHintsMatchWhatIsOffScreen(logger as Logger) as Boolean {
        var total = 4;
        if (GridScroll.hasRowsAbove(0)) {
            logger.error("nothing is above the first window");
            return false;
        }
        if (!GridScroll.hasRowsBelow(0, WINDOW, total)) {
            logger.error("row 3 is below the first window");
            return false;
        }
        if (!GridScroll.hasRowsAbove(1)) {
            logger.error("row 0 is above the scrolled window");
            return false;
        }
        if (GridScroll.hasRowsBelow(1, WINDOW, total)) {
            logger.error("nothing is below once scrolled to the end");
            return false;
        }
        // A grid that fits shows neither.
        if (GridScroll.hasRowsAbove(0) || GridScroll.hasRowsBelow(0, WINDOW, 3)) {
            logger.error("a grid that fits should show no carets at all");
            return false;
        }
        return true;
    }

}
