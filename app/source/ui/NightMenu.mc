import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Phase 0 spike (2026-10-07), what was and was not measured:
//
// Measured at runtime (UiTests.rowHeightStaysInItsClamp logs it per device):
//   fenix7pro        FONT_MEDIUM 37, SMALL 32, TINY 29, XTINY 19
//   fenix8solar47mm  FONT_MEDIUM 39, SMALL 32, TINY 29, XTINY 21
//   fr955            FONT_MEDIUM 39, SMALL 32, TINY 29, XTINY 21
// Rows were FONT_MEDIUM + 16 then (53 / 55 px), which fitted five on screen
// and ran the outer two into the round edge. Geo.Display.rowH is now a
// quarter of the display (65). Every row is drawn, and on the button
// watches drawForeground() masks what lies more than a row and a half from
// the centre (NightMenuLayout.maskBands), so a list shows three there.
//   So Chips.height() is 21 on fenix7pro and 23 on the other two.
// Read from the device files (simulator.json layouts.menu2), the platform's
// own Menu2 geometry: title 78 / 88 / 92 px high, focused item 87 / 83 / 76
// (fenix7pro / fenix8solar47mm / fr955). 78 + 87 / 2 = 121.5 on fenix7pro:
// Garmin's own menu puts the first item about centred under its title.
//
// NOT measured: the simulator in this setup (Docker, Xwayland) loaded the app
// (95.8 of 763.6 kB in the status bar) but never painted the device panel,
// and System.println() from a normal run reached neither the monkeydo output
// nor GARMIN/APPS/LOGS. So the title dc size passed to drawTitle(), the item
// dc size passed to CustomMenuItem.draw(), how much of a 120 px title shows at
// focus 0 and at focus 2, and whether onShow() fires again after a pop are
// open. Derived instead, assuming the focused row is centred (plan "Facts"):
// at focus 0 the visible title is cy - rowH / 2 = Geo heroBottom px (98
// with rows of 65), and the home title is exactly that tall; at focus 1
// the title bottom is at heroBottom - rowH = 33, so from focus 1 on
// the title lies under the mask, like a row two away from the focus. Check on
// the watch; onShow() below refreshes the theme either way. The debug build
// shows the title and row dc sizes on the watch (MenuTrace).
//
// Menus in Škoda green (B6 "Menus"): Menu2 cannot be recoloured on these
// watches (themes unsupported), so every list is a CustomMenu drawn here. A
// CustomMenu keeps Garmin's own scrolling, focus animation and key/touch
// handling; only the pixels are ours. Matches Ui.menu in the PoC. Sizes
// below are px of the 260 face, scaled with Geo.Display.px().
class NightMenu extends WatchUi.CustomMenu {

    private var _title as String;
    // Which row has the focus, for the mask's top band. Kept here rather
    // than asked of the rows: see NightMenuFocus.
    private var _focus as NightMenuFocus;
    private var _count as Number = 0;

    // titleHeight null keeps the platform default; the home passes
    // Geo.current().heroBottom because its hero lives in the title area. An option
    // with no value is left out rather than passed as null: the API types
    // allow null, but the new UI has not run on a watch yet, and a firmware
    // that checks option types would fail every list, home included.
    function initialize(title as String, focus as Number, titleHeight as Number?) {
        Theme.refresh();
        // Before CustomMenu.initialize: it calls setFocus() for :focus, which
        // this class overrides to update _focus (1.1.3 crashed at launch
        // because _focus did not exist yet; NightMenuFocusTests).
        _focus = new NightMenuFocus(focus);
        _title = title;
        var rowH = Geo.current().rowH;
        if (titleHeight != null) {
            CustomMenu.initialize(rowH, Graphics.COLOR_BLACK, {
                :focus => focus,
                :titleItemHeight => titleHeight
            });
        } else {
            CustomMenu.initialize(rowH, Graphics.COLOR_BLACK, { :focus => focus });
        }
    }

    // Monochrome flag is cached per onShow (A21), and a pop back onto a menu
    // must pick up a flag flipped meanwhile. A menu never shows the action
    // menu indicator, so the keep-out a view set before is cleared.
    function onShow() as Void {
        Theme.refresh();
        Geo.setKeepOut(false);
        MenuTrace.shown(_count);
        CustomMenu.onShow();
    }

    // The debug build keeps its menu trace across runs (MenuTrace.save).
    function onHide() as Void {
        MenuTrace.save();
        CustomMenu.onHide();
    }

    // Accent FONT_TINY title with a 1 px rule under it (PoC Ui.menu). The
    // title area ends just above the focused row at focus 0, so the text is
    // fitted to the chord at that height, not to the dc width. Drawn at
    // every focus, so it scrolls out with the list: from focus 1 on the
    // mask covers it on the button watches (drawForeground).
    function drawTitle(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        var g = Geo.current();
        var h = dc.getHeight();
        var w = dc.getWidth();
        MenuTrace.title(w, h);
        var font = Graphics.FONT_TINY;
        var fh = dc.getFontHeight(font);
        var cy = h / 2;
        // Screen y of this text at focus 0: the title's bottom is heroBottom.
        var screenCy = g.heroBottom - (h - cy);
        var maxW = g.usable(screenCy - fh / 2, screenCy + fh / 2, Theme.MARGIN);
        var margin = g.px(Theme.MARGIN);
        if (maxW > w - 2 * margin) {
            maxW = w - 2 * margin;
        }
        var s = Ui.fit(_title, maxW, Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - g.px(70), h - 2, g.px(140), 1);
    }

    // Called after the title and the rows, over the whole screen. On the
    // button watches a black band covers everything more than a row and a
    // half from the centre, so rows slide into and out of the edge by where
    // they are. Up to 1.3.0 a row was left blank by its index instead
    // (within one of the focus or not), and Garmin's scroll animation moves
    // rows while the focus is still the old one or already the new one, so
    // rows on screen went blank mid-scroll. The focus read here is this
    // frame's: every row has reported its own by now. Subclasses that draw
    // over the menu (the home ring) call this first.
    function drawForeground(dc as Dc) as Void {
        _focus.endFrame();
        MenuTrace.frame(_focus.focus());
        if (!NightMenuLayout.masks(Geo.current().input)) {
            return;
        }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bands = NightMenuLayout.maskBands(h, Geo.current().rowH, _focus.focus());
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        if (bands[0] > 0) {
            dc.fillRectangle(0, 0, w, bands[0]);
        }
        if (bands[1] < h) {
            dc.fillRectangle(0, bands[1], w, h - bands[1]);
        }
    }

    // The focus as this menu last saw it (NightMenuFocus).
    function focusState() as NightMenuFocus {
        return _focus;
    }

    // Whether the title is in view: it sits above row 0.
    function titleShown() as Boolean {
        return _focus.titleShown();
    }

    // HomeMenu moves the focus itself after rebuilding its rows.
    function setFocus(focus as Number?) as Void {
        Menu2.setFocus(focus);
        if (focus != null) {
            _focus.set(focus);
        }
    }

    // Every row learns its menu and its index here, so drawing a row never
    // has to search the list.
    function addItem(item as WatchUi.CustomMenuItem) as Void {
        if (item instanceof NightMenuItem) {
            (item as NightMenuItem).attach(self, _count);
        }
        _count += 1;
        _focus.setCount(_count);
        CustomMenu.addItem(item);
    }

    function updateItem(item as WatchUi.MenuItem, index as Number) as Void {
        if (item instanceof NightMenuItem) {
            (item as NightMenuItem).attach(self, index);
        }
        Menu2.updateItem(item, index);
    }

    // The rows after a deleted one move up a place, so every row gets its
    // index again.
    function deleteItem(index as Number) as Boolean? {
        var done = Menu2.deleteItem(index);
        var i = 0;
        var item = getItem(i);
        while (item != null) {
            if (item instanceof NightMenuItem) {
                (item as NightMenuItem).attach(self, i);
            }
            i += 1;
            item = getItem(i);
        }
        _count = i;
        _focus.setCount(_count);
        return done;
    }

    // Typed access for callers that update a row's sub-label or check.
    function itemAt(i as Number) as NightMenuItem? {
        return getItem(i) as NightMenuItem?;
    }

}

// One row: focused = accent pill with black text (white pill under
// monochrome; setPill() can give another fill), otherwise grey FONT_TINY with an accent icon, a grey FONT_XTINY
// sub-label and an accent check when set (B6, PoC Ui.menu).
class NightMenuItem extends WatchUi.CustomMenuItem {

    // Focus pill caps: 212 px wide (C1b "pill (24,120,212,40)"), at least
    // 3 px air above and below inside the 65 px row. The pill is sized from
    // its text and centred: a pill filling the row would read as a block,
    // not a button. All in px of the 260 face, scaled when drawn.
    const PILL_MAX_W = 212;
    const PILL_INSET = 3;
    const PILL_PAD = 14;
    // Check column on an unfocused row: an 8 px gap plus the r 8 mark.
    const CHECK_W = 26;
    // Widest unfocused row in the PoC.
    const NEIGHBOUR_MAX_W = 193;

    private var _label as String;
    private var _sub as String?;
    private var _icon as Symbol?;
    private var _checked as Boolean?;

    // checked null = no check column; true/false = single- or multi-choice
    // row (charge mode, tile order).
    private var _menu as WeakReference? = null;
    private var _index as Number = -1;
    // The fitted text of both states, kept between frames: draw() runs on
    // every frame of a scroll, and fitting measures (Ui.pickFont, Ui.fit).
    private var _layout as NightMenuRowCache = new NightMenuRowCache();
    // Fill of the focus pill; null is the accent. The confirmation before a
    // stop command sets Theme.DESTRUCTIVE (CommandConfirm). Not part of the
    // row cache, since the fill changes no text; the monochrome test still
    // draws the pill white. Text on it stays black, so only fills that carry
    // black text (style guide "Never put text on a grey fill").
    private var _pill as Number? = null;

    function initialize(id as Object, label as String, sub as String?, icon as Symbol?, checked as Boolean?) {
        CustomMenuItem.initialize(id, {});
        _label = label;
        _sub = sub;
        _icon = icon;
        _checked = checked;
    }

    // Named text, not label: MenuItem's own getLabel/setLabel take resource ids.
    function getText() as String {
        return _label;
    }

    // Lets a screen update a row in place so focus survives (WP1 rebuild rule).
    function setText(label as String) as Void {
        _label = label;
        _layout.clear();
    }

    function setSub(sub as String?) as Void {
        _sub = sub;
        _layout.clear();
    }

    // The check column changes the room for the text, so this clears the
    // layout as well.
    function setChecked(checked as Boolean?) as Void {
        _checked = checked;
        _layout.clear();
    }

    function setPill(color as Number?) as Void {
        _pill = color;
    }

    function pill() as Number? {
        return _pill;
    }

    // The row's laid-out text (NightMenuRowCache), for the tests.
    function layout() as NightMenuRowCache {
        return _layout;
    }

    // The menu this row is in, as a WeakReference (the menu holds its rows),
    // and the row's place in it.
    function attach(menu as NightMenu, index as Number) as Void {
        _menu = menu.weak();
        _index = index;
    }

    // Every row is drawn, whatever the focus; the menu's mask decides what
    // shows (NightMenu.drawForeground).
    function draw(dc as Dc) as Void {
        var focused = isFocused();
        MenuTrace.row(_index, focused, dc.getHeight());
        var ref = _menu;
        if (ref != null && _index >= 0) {
            var menu = ref.get() as NightMenu?;
            if (menu != null && menu.focusState().drawn(_index, focused)) {
                WatchUi.requestUpdate();
            }
        }
        if (focused) {
            _drawFocused(dc);
        } else {
            _drawPlain(dc);
        }
    }

    function _drawFocused(dc as Dc) as Void {
        var g = Geo.current();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var sub = _sub;
        var ph = NightMenuLayout.pillHeight(h,
            sub != null ? dc.getFontHeight(Graphics.FONT_SMALL) + dc.getFontHeight(Graphics.FONT_XTINY) : dc.getFontHeight(Graphics.FONT_MEDIUM),
            g.px(PILL_PAD), g.px(PILL_INSET));
        var pw = w - g.px(24);
        if (pw > g.px(PILL_MAX_W)) {
            pw = g.px(PILL_MAX_W);
        }
        var px = (w - pw) / 2;
        var py = (h - ph) / 2;
        var mid = py + ph / 2;
        var pill = _pill;
        dc.setColor(Theme.isMono() ? Theme.TEXT_1 : (pill != null ? pill : Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, ph / 2);

        var right = _checked != null ? g.px(34) : 0;
        var x = px + g.px(20);
        var icon = _icon;
        if (icon != null) {
            NightIcons.draw(dc, icon, x + g.px(8), mid, g.px(9), Theme.BG);
            x += g.px(26);
        }
        var laid = _layout.at(w, h).focused();
        if (laid == null) {
            var maxW = px + pw - g.px(20) - right - x;
            var fonts = sub != null
                ? [Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>
                : [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>;
            var font = Ui.pickFont(_label, fonts, maxW, Ui.fontMeasurer(dc));
            laid = [Ui.fit(_label, maxW, Ui.measurer(dc, font)),
                sub != null ? Ui.fit(sub, maxW, Ui.measurer(dc, Graphics.FONT_XTINY)) : null,
                font] as [String, String?, Graphics.FontType];
            _layout.setFocused(laid);
        }
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        var vjust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var subText = laid[1];
        if (subText != null) {
            dc.drawText(x, mid - ph / 5, laid[2], laid[0], vjust);
            dc.setColor(Theme.isMono() ? Theme.BG : Theme.EMERALD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, mid + ph / 4, Graphics.FONT_XTINY, subText, vjust);
        } else {
            dc.drawText(x, mid, laid[2], laid[0], vjust);
        }

        var checked = _checked;
        if (checked != null) {
            if (checked) {
                NightIcons.draw(dc, :check, px + pw - g.px(30), mid, g.px(9), Theme.BG);
            } else {
                dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(g.px(2));
                dc.drawRectangle(px + pw - g.px(39), mid - g.px(9), g.px(18), g.px(18));
                dc.setPenWidth(1);
            }
        }
    }

    // The sub-label and the check stay on unfocused rows too: "Current",
    // "Position 3", "Hidden" and "Recommended" are the reason to scan the
    // list, and Menu2 showed them on every row.
    function _drawPlain(dc as Dc) as Void {
        var g = Geo.current();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var mid = h / 2;
        var font = Graphics.FONT_TINY;
        var iconW = _icon != null ? g.px(26) : 0;
        var checked = _checked;
        var checkW = checked != null ? g.px(CHECK_W) : 0;
        var laid = _layout.at(w, h).plain();
        if (laid == null) {
            // An unfocused row in view on the button watches sits one row
            // above or below the centre (the mask hides the rest), so its text
            // is fitted to the chord there, and never wider than the PoC's
            // widest unfocused row.
            var blockH = dc.getFontHeight(font) + (_sub != null ? dc.getFontHeight(Graphics.FONT_XTINY) : 0);
            var maxW = NightMenuLayout.neighbourWidth(g, h, blockH) - iconW - checkW;
            var cap = g.px(NEIGHBOUR_MAX_W) - iconW - checkW;
            if (maxW > cap) {
                maxW = cap;
            }
            var fitted = Ui.fit(_label, maxW, Ui.measurer(dc, font));
            var fittedW = dc.getTextWidthInPixels(fitted, font);
            var sub = _sub;
            var fittedSub = null as String?;
            if (sub != null) {
                fittedSub = Ui.fit(sub, maxW, Ui.measurer(dc, Graphics.FONT_XTINY));
                var subW = dc.getTextWidthInPixels(fittedSub, Graphics.FONT_XTINY);
                if (subW > fittedW) {
                    fittedW = subW;
                }
            }
            laid = [fitted, fittedSub, fittedW] as [String, String?, Number];
            _layout.setPlain(laid);
        }
        var label = laid[0];
        var subText = laid[1];
        var textW = laid[2];
        var labelY = mid;
        var subY = mid;
        if (subText != null) {
            var ys = NightMenuLayout.plainLines(h, dc.getFontHeight(font), dc.getFontHeight(Graphics.FONT_XTINY));
            labelY = ys[0];
            subY = ys[1];
        }
        var x0 = (w - (iconW + textW + checkW)) / 2;
        var icon = _icon;
        if (icon != null) {
            NightIcons.draw(dc, icon, x0 + g.px(9), mid, g.px(8), Theme.c(Theme.ACCENT));
        }
        var vjust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + iconW, labelY, font, label, vjust);
        if (subText != null) {
            dc.drawText(x0 + iconW, subY, Graphics.FONT_XTINY, subText, vjust);
        }
        if (checked != null) {
            var cx = x0 + iconW + textW + checkW - g.px(9);
            var r = g.px(8);
            if (checked) {
                NightIcons.draw(dc, :check, cx, mid, r, Theme.c(Theme.ACCENT));
            } else {
                dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(g.px(2));
                dc.drawRectangle(cx - r, mid - r, 2 * r, 2 * r);
                dc.setPenWidth(1);
            }
        }
    }

}

// Pure row geometry, outside the item class so tests need no CustomMenuItem.
module NightMenuLayout {

    // Whether lists are masked on a watch of this input profile. In the
    // device files (simulator.json layouts menu2.mode, SDK 9.2.0) the menus
    // of every five-button watch are "touchButton", with the focused row
    // centred, and those of the seven profile B and C watches (Venu 3 and
    // 3S, vívoactive 5 and 6, Venu 4 41 and 45 mm, Venu X1) are "scroll":
    // the list is dragged and rests anywhere, 4 to 5 rows in view, so there
    // is no row two from a centred focus to hide, and nothing is masked
    // there. docs/adding-a-watch.md section 2 checks the pairing for a new
    // watch.
    function masks(input as Number) as Boolean {
        return input == Geo.INPUT_A;
    }

    // The mask over a list on a screen h px high with rows rowH apart, as
    // [bottom of the top band, top of the bottom band]: black above and
    // below a row and a half from the centre, rounded outwards, so a
    // centred focus and both its neighbours keep every pixel and the rows
    // two away are covered (at 65 px rows on a 260 face: 0 to 32 and 228
    // to 260, where only the round edge would show of them). The top band
    // is off (0) while row 0 has the focus: the title sits above it (on
    // home, the hero), and there is no row above to hide.
    //
    // Built to fail open. It assumes the focused row is centred. The device
    // files point that way for touchButton menus (the selection theme area
    // of the fēnix 8 47 mm, Forerunner 265 and 965 sits on the screen
    // centre, and there and on the Forerunner 955 Menu2's title height puts
    // its first row in the middle), but nothing states it for a CustomMenu,
    // and on the fēnix 7 Menu2's first row (78 + 87 / 2) sits 8 px above
    // the centre. Off by d px, the band takes d px from one neighbour's
    // outer edge, which is empty row up to (rowH - text) / 2 (8 px with a
    // sub-label on the fēnix 7 Pro), then cuts its text with a straight
    // edge: visible, never a whole row, and the row two away shows a sliver
    // on the other side. The default title height (menu2.title.height) does
    // not enter: at focus 0 the top band is off, and from focus 1 on the
    // title lies wholly above row 0, inside the band, however tall it is.
    function maskBands(h as Number, rowH as Number, focus as Number) as [Number, Number] {
        var half = (3 * rowH + 1) / 2;
        var top = focus == 0 ? 0 : h / 2 - half;
        var bottom = h / 2 + half;
        return [top > 0 ? top : 0, bottom < h ? bottom : h];
    }

    // Vertical centres [label, sub] of an unfocused row with a sub-label:
    // the two lines stacked as one block centred in the row. FONT_TINY over
    // FONT_XTINY is 48 to 50 px on the fēnix, inside the 65 px row
    // (Geo.Display.rowH).
    function plainLines(rowH as Number, labelH as Number, subH as Number) as [Number, Number] {
        var top = (rowH - labelH - subH) / 2;
        return [top + labelH / 2, top + labelH + subH / 2];
    }

    // Focus pill height: the text block plus padding, never taller than the
    // row minus the inset on both sides.
    function pillHeight(rowH as Number, textH as Number, pad as Number, inset as Number) as Number {
        var ph = textH + pad;
        var max = rowH - 2 * inset;
        return ph < max ? ph : max;
    }

    // Usable text width of a row one row below the centre of display g,
    // for a text block blockH tall centred in the row (the row above is
    // its mirror image).
    function neighbourWidth(g as Geo.Display, rowH as Number, blockH as Number) as Number {
        var centre = g.cy + rowH;
        return g.usable(centre - blockH / 2, centre + blockH / 2, Theme.MARGIN);
    }

}

// Which row of a NightMenu has the focus, for the mask's top band, kept
// apart from WatchUi so the unit tests can drive it frame by frame
// (NightMenuFocusTests).
//
// There is no Menu2.getFocus(), and CustomMenuItem.isFocused() is only known
// to be right for the row being drawn: 1.1.1 drew its focus pill from it and
// that was right on the watch. 1.1.2 at first asked every row for
// isFocused() while drawing one, and on the watch the first frames of a
// menu then hid the rows that were on screen until a later redraw. So the
// focus here starts at the focus the menu was opened with and follows only
// the row being drawn reporting its own focus. A frame ends in
// NightMenu.drawForeground (endFrame).
class NightMenuFocus {

    private var _focus as Number;
    // Number of rows, once known; -1 until the first row is added.
    private var _count as Number = -1;
    // The first row to report focus in this frame, -1 while none has. Two
    // rows reporting focus at once is known from the forum (the Venu 3, and
    // the old and new row after setFocus); the first one in a frame decides,
    // the row already focused included, and the second is ignored, so the
    // focus cannot swing between the two from frame to frame.
    private var _mover as Number = -1;

    function initialize(focus as Number) {
        _focus = focus < 0 ? 0 : focus;
    }

    // The focused row, clamped to the rows there are (the platform does the
    // same with an out-of-range :focus).
    function focus() as Number {
        if (_count > 0 && _focus > _count - 1) {
            return _count - 1;
        }
        return _focus;
    }

    function set(focus as Number) as Void {
        _focus = focus < 0 ? 0 : focus;
    }

    function setCount(count as Number) as Void {
        _count = count;
    }

    // Every row reports here as it draws, with its own focus state. Returns
    // true when the caller should ask for one more frame: only when the
    // move shows or hides the title, the one thing the focus still decides,
    // and at most once per frame. drawForeground reads the focus after the
    // rows, so on a watch that draws as documented this frame is spare; it
    // is a safety net, where up to 1.3.0 every move asked for one (and two
    // rows reporting focus could ask forever).
    function drawn(index as Number, focused as Boolean) as Boolean {
        if (index == _mover) {
            // The row that decided the focus draws again: a new frame, even
            // if drawForeground did not end the last one.
            _mover = -1;
        }
        if (!focused || _mover >= 0) {
            return false;
        }
        if (index == focus()) {
            _mover = index;
            return false;
        }
        var titleWas = titleShown();
        _focus = index;
        _mover = index;
        return titleShown() != titleWas;
    }

    // NightMenu.drawForeground, after every row of the frame.
    function endFrame() as Void {
        _mover = -1;
    }

    // The title sits above row 0.
    function titleShown() as Boolean {
        return focus() == 0;
    }

}

// The fitted text of one NightMenuItem, per state, laid out on its first
// draw and kept until the row changes (setText, setSub, setChecked) or is
// drawn into a dc of another size. Focused: [label, sub-label or null,
// label font]. Plain: [label, sub-label or null, width of the wider].
class NightMenuRowCache {

    private var _w as Number = -1;
    private var _h as Number = -1;
    private var _focused as [String, String?, Graphics.FontType]? = null;
    private var _plain as [String, String?, Number]? = null;

    // The cache for a row dc of w by h; a different size drops both states.
    function at(w as Number, h as Number) as NightMenuRowCache {
        if (w != _w || h != _h) {
            clear();
            _w = w;
            _h = h;
        }
        return self;
    }

    function focused() as [String, String?, Graphics.FontType]? {
        return _focused;
    }

    function setFocused(laid as [String, String?, Graphics.FontType]) as Void {
        _focused = laid;
    }

    function plain() as [String, String?, Number]? {
        return _plain;
    }

    function setPlain(laid as [String, String?, Number]) as Void {
        _plain = laid;
    }

    function clear() as Void {
        _focused = null;
        _plain = null;
    }

}

// Shared input for every NightMenu: select either pops first (pickers) or
// leaves the menu up (action lists that push further), then hands the id to
// onPick(). Subclasses that call back into a view hold it as a WeakReference
// (docs/best-practices "Break reference cycles").
class NightMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _popOnSelect as Boolean;

    function initialize(popOnSelect as Boolean) {
        Menu2InputDelegate.initialize();
        _popOnSelect = popOnSelect;
    }

    // Pops before onPick() so a confirmation or toast pushed by onPick()
    // lands on the screen underneath, not on the menu being closed (A14).
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (_popOnSelect) {
            WatchUi.popView(Theme.SLIDE_OUT);
        }
        onPick(item.getId());
    }

    // Override in the screen's delegate; the base does nothing.
    function onPick(id as Object?) as Void {
    }

    // Back always slides right, the mirror of the drill-in (A20).
    function onBack() as Void {
        WatchUi.popView(Theme.SLIDE_OUT);
    }

}
