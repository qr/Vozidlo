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
// and ran the outer two into the round edge. Theme.rowHeight() is now a
// quarter of the display (65) and only the focused row and its two
// neighbours are drawn (NightMenuLayout.isShown), so every list shows three.
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
// at focus 0 the visible title is 130 - rowHeight / 2 = heroBottom() px
// (98 with rows of 65), and Theme.HOME_TITLE_H is exactly that; at focus 1
// the title bottom is at heroBottom() - rowHeight = 33, so from focus 1 on
// the title is drawn blank, like a row two away from the focus. Check on the
// watch; onShow() below refreshes the theme either way.
//
// Menus in Škoda green (B6 "Menus"): Menu2 cannot be recoloured on these
// watches (themes unsupported), so every list is a CustomMenu drawn here. A
// CustomMenu keeps Garmin's own scrolling, focus animation and key/touch
// handling; only the pixels are ours. Matches Ui.menu in the PoC.
class NightMenu extends WatchUi.CustomMenu {

    private var _title as String;
    // Which row has the focus, for leaving the far rows blank. Kept here
    // rather than asked of the rows: see NightMenuFocus.
    private var _focus as NightMenuFocus;
    private var _count as Number = 0;

    // titleHeight null keeps the platform default; the home passes
    // Theme.HOME_TITLE_H because its hero lives in the title area. An option
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
        if (titleHeight != null) {
            CustomMenu.initialize(Theme.rowHeight(), Graphics.COLOR_BLACK, {
                :focus => focus,
                :titleItemHeight => titleHeight
            });
        } else {
            CustomMenu.initialize(Theme.rowHeight(), Graphics.COLOR_BLACK, { :focus => focus });
        }
    }

    // Monochrome flag is cached per onShow (A21), and a pop back onto a menu
    // must pick up a flag flipped meanwhile.
    function onShow() as Void {
        Theme.refresh();
        CustomMenu.onShow();
    }

    // Accent FONT_TINY title with a 1 px rule under it (PoC Ui.menu). The
    // title area ends just above the focused row at focus 0, so the text is
    // fitted to the chord at that height, not to the dc width.
    function drawTitle(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        if (!titleShown()) {
            return;
        }
        var h = dc.getHeight();
        var w = dc.getWidth();
        var font = Graphics.FONT_TINY;
        var fh = dc.getFontHeight(font);
        var cy = h / 2;
        // Screen y of this text at focus 0: the title's bottom is heroBottom().
        var screenCy = Theme.heroBottom() - (h - cy);
        var maxW = Ui.usable(screenCy - fh / 2, screenCy + fh / 2, Theme.MARGIN);
        if (maxW > w - 2 * Theme.MARGIN) {
            maxW = w - 2 * Theme.MARGIN;
        }
        var s = Ui.fit(_title, maxW, Ui.measurer(dc, font));
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.c(Theme.RULE), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - 70, h - 2, 140, 1);
    }

    // The focus as this menu last saw it (NightMenuFocus).
    function focusState() as NightMenuFocus {
        return _focus;
    }

    // Whether the title is on screen: it sits where row -1 would.
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
// monochrome), otherwise grey FONT_TINY with an accent icon, a grey FONT_XTINY
// sub-label and an accent check when set (B6, PoC Ui.menu).
class NightMenuItem extends WatchUi.CustomMenuItem {

    // Focus pill caps: 212 px wide (C1b "pill (24,120,212,40)"), at least
    // 3 px air above and below inside the 65 px row. The pill is sized from
    // its text and centred: a pill filling the row would read as a block,
    // not a button.
    const PILL_MAX_W = 212;
    const PILL_INSET = 3;
    const PILL_PAD = 14;
    // Check column on an unfocused row: an 8 px gap plus the r 8 mark.
    const CHECK_W = 26;

    private var _label as String;
    private var _sub as String?;
    private var _icon as Symbol?;
    private var _checked as Boolean?;

    // checked null = no check column; true/false = single- or multi-choice
    // row (charge mode, tile order).
    private var _menu as WeakReference? = null;
    private var _index as Number = -1;

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
    }

    function setSub(sub as String?) as Void {
        _sub = sub;
    }

    function setChecked(checked as Boolean?) as Void {
        _checked = checked;
    }

    // The menu this row is in, as a WeakReference (the menu holds its rows),
    // and the row's place in it.
    function attach(menu as NightMenu, index as Number) as Void {
        _menu = menu.weak();
        _index = index;
    }

    function draw(dc as Dc) as Void {
        var focused = isFocused();
        var ref = _menu;
        if (ref != null && _index >= 0) {
            var menu = ref.get() as NightMenu?;
            if (menu != null) {
                var state = menu.focusState();
                // Rows drawn earlier in this frame went by the old focus:
                // one more frame puts every row right.
                if (state.drawn(_index, focused)) {
                    WatchUi.requestUpdate();
                }
                if (!state.shows(_index, focused)) {
                    return;
                }
            }
        }
        if (focused) {
            _drawFocused(dc);
        } else {
            _drawPlain(dc);
        }
    }

    function _drawFocused(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var sub = _sub;
        var ph = NightMenuLayout.pillHeight(h,
            sub != null ? dc.getFontHeight(Graphics.FONT_SMALL) + dc.getFontHeight(Graphics.FONT_XTINY) : dc.getFontHeight(Graphics.FONT_MEDIUM),
            PILL_PAD, PILL_INSET);
        var pw = w - 24;
        if (pw > PILL_MAX_W) {
            pw = PILL_MAX_W;
        }
        var px = (w - pw) / 2;
        var py = (h - ph) / 2;
        var mid = py + ph / 2;
        dc.setColor(Theme.isMono() ? Theme.TEXT_1 : Theme.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, ph / 2);

        var right = _checked != null ? 34 : 0;
        var x = px + 20;
        var icon = _icon;
        if (icon != null) {
            NightIcons.draw(dc, icon, x + 8, mid, 9, Theme.BG);
            x += 26;
        }
        var maxW = px + pw - 20 - right - x;
        var fonts = sub != null
            ? [Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>
            : [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>;
        var font = Ui.pickFont(_label, fonts, maxW, Ui.fontMeasurer(dc));
        var label = Ui.fit(_label, maxW, Ui.measurer(dc, font));
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        var vjust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        if (sub != null) {
            dc.drawText(x, mid - ph / 5, font, label, vjust);
            var subText = Ui.fit(sub, maxW, Ui.measurer(dc, Graphics.FONT_XTINY));
            dc.setColor(Theme.isMono() ? Theme.BG : Theme.EMERALD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, mid + ph / 4, Graphics.FONT_XTINY, subText, vjust);
        } else {
            dc.drawText(x, mid, font, label, vjust);
        }

        var checked = _checked;
        if (checked != null) {
            if (checked) {
                NightIcons.draw(dc, :check, px + pw - 30, mid, 9, Theme.BG);
            } else {
                dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawRectangle(px + pw - 39, mid - 9, 18, 18);
                dc.setPenWidth(1);
            }
        }
    }

    // The sub-label and the check stay on unfocused rows too: "Current",
    // "Position 3", "Hidden" and "Recommended" are the reason to scan the
    // list, and Menu2 showed them on every row.
    function _drawPlain(dc as Dc) as Void {
        var w = dc.getWidth();
        var mid = dc.getHeight() / 2;
        var font = Graphics.FONT_TINY;
        var iconW = _icon != null ? 26 : 0;
        var checked = _checked;
        var checkW = checked != null ? CHECK_W : 0;
        // An unfocused row that is on screen sits one row above or below the
        // centre (three rows per screen), so its text is fitted to the chord
        // there; 193 = the PoC's widest unfocused row.
        var blockH = dc.getFontHeight(font) + (_sub != null ? dc.getFontHeight(Graphics.FONT_XTINY) : 0);
        var maxW = NightMenuLayout.neighbourWidth(dc.getHeight(), blockH) - iconW - checkW;
        if (maxW > 193 - iconW - checkW) {
            maxW = 193 - iconW - checkW;
        }
        var label = Ui.fit(_label, maxW, Ui.measurer(dc, font));
        var textW = dc.getTextWidthInPixels(label, font);
        var sub = _sub;
        var subText = null as String?;
        var labelY = mid;
        var subY = mid;
        if (sub != null) {
            subText = Ui.fit(sub, maxW, Ui.measurer(dc, Graphics.FONT_XTINY));
            var subW = dc.getTextWidthInPixels(subText, Graphics.FONT_XTINY);
            if (subW > textW) {
                textW = subW;
            }
            var ys = NightMenuLayout.plainLines(dc.getHeight(), dc.getFontHeight(font), dc.getFontHeight(Graphics.FONT_XTINY));
            labelY = ys[0];
            subY = ys[1];
        }
        var x0 = (w - (iconW + textW + checkW)) / 2;
        var icon = _icon;
        if (icon != null) {
            NightIcons.draw(dc, icon, x0 + 9, mid, 8, Theme.c(Theme.ACCENT));
        }
        var vjust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + iconW, labelY, font, label, vjust);
        if (subText != null) {
            dc.drawText(x0 + iconW, subY, Graphics.FONT_XTINY, subText, vjust);
        }
        if (checked != null) {
            var cx = x0 + iconW + textW + checkW - 9;
            if (checked) {
                NightIcons.draw(dc, :check, cx, mid, 8, Theme.c(Theme.ACCENT));
            } else {
                dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawRectangle(cx - 8, mid - 8, 16, 16);
                dc.setPenWidth(1);
            }
        }
    }

}

// Pure row geometry, outside the item class so tests need no CustomMenuItem.
module NightMenuLayout {

    // Rows (and the title, at index -1) more than one row from the focus are
    // left blank: at a 65 px pitch they would sit in the round edge, cut off.
    // An unknown focus (-1) shows everything.
    function isShown(index as Number, focus as Number) as Boolean {
        if (focus < 0) {
            return true;
        }
        var d = index - focus;
        return d >= -1 && d <= 1;
    }

    // Vertical centres [label, sub] of an unfocused row with a sub-label:
    // the two lines stacked as one block centred in the row. FONT_TINY over
    // FONT_XTINY is 48 to 50 px on the targets, inside the 65 px row
    // (Theme.rowHeight()).
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

    // Usable text width of a row one row away from the centre of a round
    // 260 px display, for a text block blockH tall centred in the row.
    function neighbourWidth(rowH as Number, blockH as Number) as Number {
        var centre = 130 + rowH;
        return Ui.usable(centre - blockH / 2, centre + blockH / 2, Theme.MARGIN);
    }

}

// Which rows of a NightMenu are drawn, kept apart from WatchUi so the unit
// tests can drive it frame by frame (NightMenuFocusTests).
//
// There is no Menu2.getFocus(), and CustomMenuItem.isFocused() is only known
// to be right for the row being drawn: 1.1.1 drew its focus pill from it and
// that was right on the watch. 1.1.2 at first asked every row for
// isFocused() while drawing one, and on the watch the first frames of a
// menu then hid the rows that were on screen until a later redraw. So the
// focus here starts at the focus the menu was opened with, follows only the
// row being drawn reporting its own focus, and the caller asks for one more
// frame when it moved.
class NightMenuFocus {

    private var _focus as Number;
    // Number of rows, once known; -1 until the first row is added.
    private var _count as Number = -1;

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
    // true when that moved the focus: rows drawn before it in the same frame
    // went by the old one, so the caller asks for another frame.
    function drawn(index as Number, focused as Boolean) as Boolean {
        if (!focused || index == focus()) {
            return false;
        }
        _focus = index;
        return true;
    }

    // A row is drawn when it is the focus or next to it; the focused row
    // always, whatever was tracked before.
    function shows(index as Number, focused as Boolean) as Boolean {
        return focused || NightMenuLayout.isShown(index, focus());
    }

    // The title sits where row -1 would.
    function titleShown() as Boolean {
        return NightMenuLayout.isShown(-1, focus());
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
