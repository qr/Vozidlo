import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// What the firmware does while a list scrolls, recorded in the debug build
// only. Garmin documents neither when CustomMenuItem.isFocused() changes
// during a scroll animation (at its start, at its end, or with a drag) nor
// the order rows are drawn in, and the forum reports two rows focused at
// once on the Venu 3. System.println() reaches no log on a sideloaded watch,
// so every row draw goes into a ring buffer (System.getTimer(), row,
// isFocused()), with a mark at the end of each frame (the focus the mask
// used) and when a list opens, and a screen shows it on the watch: the
// "Menu trace" row at the end of home (HomeMenu._addTraceRow). It also shows
// the title and row dc sizes, which no Garmin document gives for a
// CustomMenu. A list saves the buffer to Storage when it closes, because the
// temperature list runs as the app's settings view (getSettingsView), apart
// from home; the next run picks it up and adds to it. Timings and row
// numbers only, nothing about the user or the car.
//
// A release build compiles only the empty functions at the end: no buffer,
// no screen, no row, nothing stored. The same (:debug)/(:release) split as
// Endpoints.baseUrl().
module MenuTrace {

    // About 40 frames of five rows; a frame of a list opening draws every row.
    (:debug) const SIZE = 300;
    // In the row column next to a row index: the end of a frame (focus
    // column: the focus the mask used) and a list opening (its row count).
    (:debug) const FRAME = -1;
    (:debug) const SHOWN = -2;
    (:debug) const ROW = :menuTrace;
    (:debug) const STORAGE_KEY = "menuTrace";

    (:debug) var _at as Array<Number> = [] as Array<Number>;
    (:debug) var _row as Array<Number> = [] as Array<Number>;
    (:debug) var _focus as Array<Number> = [] as Array<Number>;
    (:debug) var _next as Number = 0;
    (:debug) var _titleW as Number = -1;
    (:debug) var _titleH as Number = -1;
    (:debug) var _rowH as Number = -1;
    (:debug) var _loaded as Boolean = false;

    (:debug)
    function row(index as Number, focused as Boolean, h as Number) as Void {
        _rowH = h;
        _add(index, focused ? 1 : 0);
    }

    (:debug)
    function frame(focus as Number) as Void {
        _add(FRAME, focus);
    }

    (:debug)
    function shown(count as Number) as Void {
        _add(SHOWN, count);
    }

    (:debug)
    function title(w as Number, h as Number) as Void {
        _titleW = w;
        _titleH = h;
    }

    (:debug)
    function clear() as Void {
        _at = [] as Array<Number>;
        _row = [] as Array<Number>;
        _focus = [] as Array<Number>;
        _next = 0;
        _loaded = true;
        Storage.deleteValue(STORAGE_KEY);
    }

    // NightMenu.onHide: once per list closing, never per frame.
    (:debug)
    function save() as Void {
        _load();
        Storage.setValue(STORAGE_KEY, [_at, _row, _focus, _next] as Array<Storage.ValueType>);
    }

    // What an earlier run saved, before anything is added or shown.
    (:debug)
    function _load() as Void {
        if (_loaded) {
            return;
        }
        _loaded = true;
        var saved = Storage.getValue(STORAGE_KEY);
        if (saved instanceof Array && saved.size() == 4) {
            _at = saved[0] as Array<Number>;
            _row = saved[1] as Array<Number>;
            _focus = saved[2] as Array<Number>;
            _next = saved[3] as Number;
        }
    }

    (:debug)
    function _add(row as Number, focus as Number) as Void {
        _load();
        var t = System.getTimer();
        if (_at.size() < SIZE) {
            _at.add(t);
            _row.add(row);
            _focus.add(focus);
            return;
        }
        _at[_next] = t;
        _row[_next] = row;
        _focus[_next] = focus;
        _next = (_next + 1) % SIZE;
    }

    // One line per frame, newest first: ms since the oldest entry, ms since
    // the frame before, the rows drawn (first to last index), the rows that
    // reported focus ("f-" none, "f3,4" two) and the focus the mask used.
    // Rows after the last frame end show as one line ending in "no end".
    // System.getTimer() restarts with the watch, so across a saved run the
    // times can jump; "list, n rows" marks each list opening.
    (:debug)
    function lines() as Array<String> {
        _load();
        var out = [] as Array<String>;
        var n = _at.size();
        if (n == 0) {
            return out;
        }
        var start = n < SIZE ? 0 : _next;
        var t0 = _at[start];
        var last = t0;
        var lo = -1;
        var hi = -1;
        var focused = "";
        for (var k = 0; k < n; k += 1) {
            var i = (start + k) % n;
            var r = _row[i];
            var t = _at[i];
            if (r == SHOWN) {
                out.add((t - t0).toString() + " list, " + _focus[i].toString() + " rows");
                last = t;
            } else if (r == FRAME) {
                out.add(_frameLine(t - t0, t - last, lo, hi, focused) + " m" + _focus[i].toString());
                last = t;
                lo = -1;
                hi = -1;
                focused = "";
            } else {
                if (lo < 0 || r < lo) {
                    lo = r;
                }
                if (r > hi) {
                    hi = r;
                }
                if (_focus[i] == 1) {
                    focused += (focused.length() > 0 ? "," : "") + r.toString();
                }
            }
        }
        if (lo >= 0) {
            out.add(_frameLine(_at[(start + n - 1) % n] - t0, 0, lo, hi, focused) + " no end");
        }
        var newest = [] as Array<String>;
        for (var j = out.size() - 1; j >= 0; j -= 1) {
            newest.add(out[j]);
        }
        return newest;
    }

    (:debug)
    function _frameLine(t as Number, dt as Number, lo as Number, hi as Number, focused as String) as String {
        var rows = lo < 0 ? "-" : lo.toString() + "-" + hi.toString();
        return t.toString() + " +" + dt.toString() + " " + rows + " f" + (focused.length() > 0 ? focused : "-");
    }

    // "title 260x98 row 65": the dc sizes seen last.
    (:debug)
    function sizes() as String {
        return "title " + _titleW.toString() + "x" + _titleH.toString() + " row " + _rowH.toString();
    }

    (:debug)
    function open() as Void {
        var view = new MenuTraceView();
        WatchUi.pushView(view, new MenuTraceDelegate(view), Theme.SLIDE_IN);
    }

    (:release)
    function row(index as Number, focused as Boolean, h as Number) as Void {
    }

    (:release)
    function frame(focus as Number) as Void {
    }

    (:release)
    function shown(count as Number) as Void {
    }

    (:release)
    function title(w as Number, h as Number) as Void {
    }

    (:release)
    function save() as Void {
    }

}

// The trace as it was when the screen opened, a page of lines at a time.
(:debug)
class MenuTraceView extends WatchUi.View {

    private var _lines as Array<String> = [] as Array<String>;
    private var _first as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        Theme.refresh();
        _lines = MenuTrace.lines();
        _first = 0;
    }

    // Lines that fit between a fifth from the top and a fifth from the
    // bottom, where the chord leaves room for them on a round face.
    function pageSize() as Number {
        var g = Geo.current();
        return (g.h * 3 / 5) / g.fonts.xtinyH - 1;
    }

    // +1 is the next (older) page, -1 the previous one.
    function page(step as Number) as Void {
        var next = _first + step * pageSize();
        if (next >= 0 && next < _lines.size()) {
            _first = next;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        var g = Geo.current();
        var font = Graphics.FONT_XTINY;
        var lh = g.fonts.xtinyH;
        var y = g.h / 5;
        var head = MenuTrace.sizes() + "  " + _lines.size().toString() + " lines";
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(g.cx, y, font, Ui.fit(head, g.usable(y, y + lh, Theme.MARGIN), Ui.measurer(dc, font)),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.c(Theme.TEXT_1), Graphics.COLOR_TRANSPARENT);
        var last = _first + pageSize();
        for (var i = _first; i < last && i < _lines.size(); i += 1) {
            y += lh;
            dc.drawText(g.cx, y, font, Ui.fit(_lines[i], g.usable(y, y + lh, Theme.MARGIN), Ui.measurer(dc, font)),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

}

// DOWN or a swipe up: older lines; UP or a swipe down: newer. START clears
// the trace and goes back, so the next scroll is recorded from the start.
(:debug)
class MenuTraceDelegate extends WatchUi.BehaviorDelegate {

    // Weak: the view and its delegate are pushed together
    // (docs/best-practices "Break reference cycles").
    private var _view as WeakReference;

    function initialize(view as MenuTraceView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onNextPage() as Boolean {
        _page(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _page(-1);
        return true;
    }

    function onSelect() as Boolean {
        MenuTrace.clear();
        WatchUi.popView(Theme.SLIDE_OUT);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(Theme.SLIDE_OUT);
        return true;
    }

    function _page(step as Number) as Void {
        var view = _view.get() as MenuTraceView?;
        if (view != null) {
            view.page(step);
        }
    }

}
