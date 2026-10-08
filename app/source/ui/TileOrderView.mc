import Toybox.Lang;
import Toybox.WatchUi;

// US-061: the on-device screen for reordering and hiding the home rows,
// reached from the home's Settings row (SettingsScreen.openTileOrder()).
// A NightMenu (PoC NSet.order): each row shows its category with an icon and
// the current value as sub-label ("Position 2" or "Hidden"); selecting it
// opens a second menu for the change, the pattern docs/best-practices
// recommends ("open a secondary menu while showing the current value as
// sub-text on the parent item").
class TileOrderView extends NightMenu {

    // Snapshot of what's on screen right now, rebuilt by refreshLabels()
    // after every change: index i here is always the row at index i.
    private var _categories as Array<Symbol>;

    function initialize() {
        NightMenu.initialize("Tile order", 0, null);
        _categories = TileOrder.orderableCategories(HomeRows.supported());
        for (var i = 0; i < _categories.size(); i += 1) {
            var category = _categories[i] as Symbol;
            addItem(new NightMenuItem(category, TileOrder.label(category), _subLabel(category, i), _icon(category), null));
        }
    }

    // Called after every move/hide commit so the sub-labels reflect the
    // just-saved state without backing out and in again. A move changes
    // which category sits at which index, so whole rows are replaced (the id
    // goes with the row), then the focus follows the category that moved
    // (A20), so a second "Move up" is one more press, not a hunt.
    function refreshLabels(focusOn as Symbol) as Void {
        _categories = TileOrder.orderableCategories(HomeRows.supported());
        var focus = 0;
        for (var i = 0; i < _categories.size(); i += 1) {
            var category = _categories[i] as Symbol;
            updateItem(new NightMenuItem(category, TileOrder.label(category), _subLabel(category, i), _icon(category), null), i);
            if (category == focusOn) {
                focus = i;
            }
        }
        setFocus(focus);
    }

    function _subLabel(category as Symbol, position as Number) as String {
        if (TileOrder.isHidden(category)) {
            return "Hidden";
        }
        return "Position " + (position + 1).toString();
    }

    // Same icons as the home rows they stand for (PoC NSet.ORDER); the
    // start/stop charging pair uses the plug so it reads apart from the
    // Charging detail row's bolt.
    function _icon(category as Symbol) as Symbol {
        if (category == TileOrder.CATEGORY_CLIMATE) {
            return :fan;
        }
        if (category == TileOrder.CATEGORY_CHARGING) {
            return StateIcons.PLUGGED_IN;
        }
        if (category == TileOrder.CATEGORY_CHARGING_DETAIL) {
            return :bolt;
        }
        if (category == TileOrder.CATEGORY_FIND_MY_CAR) {
            return :pin;
        }
        if (category == TileOrder.CATEGORY_STATUS_DETAIL) {
            return :list;
        }
        return :gear;
    }

}

class TileOrderDelegate extends NightMenuDelegate {

    // Weak, per docs/best-practices: this delegate is owned by the view it
    // acts on, same convention as every other delegate in this app.
    private var _view as WeakReference;

    function initialize(view as TileOrderView) {
        NightMenuDelegate.initialize(false);
        _view = view.weak();
    }

    function onPick(id as Object?) as Void {
        var category = id as Symbol;
        var isHidden = TileOrder.isHidden(category);
        var detail = new NightMenu(TileOrder.label(category), 0, null);
        detail.addItem(new NightMenuItem(:moveUp, "Move up", null, null, null));
        detail.addItem(new NightMenuItem(:moveDown, "Move down", null, null, null));
        // No Hide for Settings: it is the way back to this screen.
        if (TileOrder.isHideable(category)) {
            detail.addItem(new NightMenuItem(:toggleHidden, isHidden ? "Show" : "Hide", null, null, null));
        }
        WatchUi.pushView(detail, new TileOrderDetailDelegate(category, self), Theme.SLIDE_IN);
    }

    // Called by TileOrderDetailDelegate once a change has been committed.
    function refreshView(moved as Symbol) as Void {
        if (!_view.stillAlive()) {
            return;
        }
        var view = _view.get() as TileOrderView?;
        if (view != null) {
            view.refreshLabels(moved);
            WatchUi.requestUpdate();
        }
    }

}

// The secondary menu for one category: move up, move down, hide/show. Pops
// itself before applying the change (NightMenuDelegate(true)), so the list
// underneath is what the user sees updated.
class TileOrderDetailDelegate extends NightMenuDelegate {

    private var _category as Symbol;
    private var _parent as WeakReference;

    function initialize(category as Symbol, parent as TileOrderDelegate) {
        NightMenuDelegate.initialize(true);
        _category = category;
        _parent = parent.weak();
    }

    function onPick(id as Object?) as Void {
        if (id == :moveUp) {
            TileOrder.moveUp(_category);
        } else if (id == :moveDown) {
            TileOrder.moveDown(_category);
        } else if (id == :toggleHidden) {
            TileOrder.toggleHidden(_category);
        }
        if (_parent.stillAlive()) {
            var parent = _parent.get() as TileOrderDelegate?;
            if (parent != null) {
                parent.refreshView(_category);
            }
        }
    }

}
