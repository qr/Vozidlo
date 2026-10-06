import Toybox.Lang;

// Scrolling arithmetic for the control grid, as pure functions.
//
// Why the grid has to scroll at all: this is a ROUND display. A row of two
// 90-pixel tiles spans 190 pixels, 95 either side of centre, so it only fits
// where the chord is at least that wide. On a 260-pixel face that is
// sqrt(130^2 - dy^2) >= 95, which gives dy <= 88 and a usable band of roughly
// y 42 to 218. At a 52-pixel row pitch that holds three rows, not four.
//
// Seven tiles need four rows. The fourth sat at y 208 to 254, where the chord
// is only 78 pixels wide, so the "More" tile was drawn under the bezel and cut
// off. Found on a watch, not in the simulator, whose bezel is generous.
//
// So: show a window of rows and move it, keeping the focused tile whole. All
// of that is this one function, kept free of Dc and Selectable so
// tests/GridScrollTests.mc can check the boundaries without a device.
module GridScroll {

    // How many rows `count` tiles occupy at `columns` per row.
    function rowCount(count as Number, columns as Number) as Number {
        if (count <= 0 || columns <= 0) {
            return 0;
        }
        return (count + columns - 1) / columns;
    }

    // The smallest change to `current` that puts `row` fully inside a window
    // of `visibleRows`, clamped so the window never scrolls past either end.
    //
    // "Smallest change" is what makes it feel like a list rather than a
    // pager: moving down one row off the bottom edge scrolls by exactly one
    // row, and moving back up scrolls back by one, instead of jumping the
    // window to centre the focus.
    function offsetFor(current as Number, row as Number,
                       visibleRows as Number, totalRows as Number) as Number {
        if (visibleRows <= 0 || totalRows <= 0) {
            return 0;
        }

        var offset = current;
        if (row < offset) {
            offset = row;                        // scrolled above the window
        } else if (row > offset + visibleRows - 1) {
            offset = row - visibleRows + 1;      // scrolled below the window
        }

        // Never leave empty space at the bottom, and never scroll above the
        // first row. The max matters when the window is larger than the
        // content, where totalRows - visibleRows goes negative.
        var maxOffset = totalRows - visibleRows;
        if (maxOffset < 0) {
            maxOffset = 0;
        }
        if (offset > maxOffset) {
            offset = maxOffset;
        }
        if (offset < 0) {
            offset = 0;
        }
        return offset;
    }

    // Whether there is anything above or below the current window, which is
    // what the caret indicators are drawn from. A grid that fits entirely on
    // screen reports neither, so it shows no scroll furniture at all.
    function hasRowsAbove(offset as Number) as Boolean {
        return offset > 0;
    }

    function hasRowsBelow(offset as Number, visibleRows as Number, totalRows as Number) as Boolean {
        return offset + visibleRows < totalRows;
    }

}
