import Toybox.Lang;
import Toybox.WatchUi;

// US-061: the on-device screen for reordering and hiding control tiles.
// Reached from the "Settings" tile ControlsView adds (see that file's
// :openTileOrder branch) rather than via AppBase.getSettingsView(): that
// hook already belongs to task 7's TargetTemperatureSettingsView, and this
// task's file-ownership split does not extend to VozidloApp.mc beyond
// getGlanceView(), see this task's final report for the full reasoning.
//
// Menu2, not the legacy Menu (docs/best-practices): well under the ~7-item
// guidance since there are only ever five categories. Each item's sub-label
// shows the current value (position, or "Hidden") and selecting it opens a
// secondary menu for the actual change: exactly the pattern
// docs/best-practices recommends: "for other choices open a secondary menu
// while showing the current value as sub-text on the parent item."
class TileOrderView extends WatchUi.Menu2 {

    // Snapshot of what's on screen right now, rebuilt by refreshLabels()
    // after every change: index i here is always the MenuItem at index i.
    private var _categories as Array<Symbol>;

    function initialize() {
        var categories = TileOrder.orderableCategories(_supportedCategories());
        Menu2.initialize({ :title => "Tile order" });
        _categories = categories;
        for (var i = 0; i < categories.size(); i += 1) {
            var category = categories[i] as Symbol;
            addItem(new WatchUi.MenuItem(TileOrder.label(category), _subLabel(category, i), category, null));
        }
    }

    // Called after every move/hide commit so the sub-labels reflect the
    // just-saved state without the user backing all the way out and in
    // again. Recomputes `_categories` first: a move can change which
    // category sits at which index, and Menu2.updateItem() replaces a
    // MenuItem wholesale (title included), so the label must be right too.
    function refreshLabels() as Void {
        _categories = TileOrder.orderableCategories(_supportedCategories());
        for (var i = 0; i < _categories.size(); i += 1) {
            var category = _categories[i] as Symbol;
            updateItem(new WatchUi.MenuItem(TileOrder.label(category), _subLabel(category, i), category, null), i);
        }
    }

    function _subLabel(category as Symbol, position as Number) as String {
        if (TileOrder.isHidden(category)) {
            return "Hidden";
        }
        return "Position " + (position + 1).toString();
    }

    // Same classification ControlsView._buildTiles() uses for its own
    // grid, see TileOrder.isChargingOperation()'s own comment on why this
    // lives in TileOrder rather than being duplicated in both files.
    function _supportedCategories() as Array<Symbol> {
        var settings = getApp().getSettings();
        var operations = Cache.operations() as Array<String>?;
        var candidates = ControlTiles.visibleCandidates(operations, settings.hasSpin);
        var hasClimateTile = false;
        var hasChargingTile = false;
        for (var i = 0; i < candidates.size(); i += 1) {
            var candidate = candidates[i] as ControlTiles.Candidate;
            if (TileOrder.isChargingOperation(candidate.operation)) {
                hasChargingTile = true;
            } else {
                hasClimateTile = true;
            }
        }
        // Same flag ControlsView._buildTiles() passes for its own grid
        // (task 9's ParkingFeature.isKnownUnsupported(), see ui/LocationView.mc)
        //: this screen must offer exactly what the landing screen offers,
        // never less.
        return TileOrder.supportedCategories(hasClimateTile, hasChargingTile, !ParkingFeature.isKnownUnsupported());
    }

}

// The secondary menu for one category: move up, move down, hide/show.
class TileOrderDetailMenu extends WatchUi.Menu2 {

    public var category as Symbol;

    function initialize(forCategory as Symbol) {
        Menu2.initialize({ :title => TileOrder.label(forCategory) });
        category = forCategory;
        addItem(new WatchUi.MenuItem("Move up", null, :moveUp, null));
        addItem(new WatchUi.MenuItem("Move down", null, :moveDown, null));
        addItem(new WatchUi.MenuItem(TileOrder.isHidden(forCategory) ? "Show" : "Hide", null, :toggleHidden, null));
    }

}

class TileOrderDelegate extends WatchUi.Menu2InputDelegate {

    // Weak, per docs/best-practices: this delegate is owned by the view
    // it acts on, same convention as every other delegate in this app.
    private var _view as WeakReference;

    function initialize(view as TileOrderView) {
        Menu2InputDelegate.initialize();
        _view = view.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var category = item.getId() as Symbol;
        var detail = new TileOrderDetailMenu(category);
        WatchUi.pushView(detail, new TileOrderDetailDelegate(detail, self), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // Called by TileOrderDetailDelegate once a change has been committed.
    function refreshView() as Void {
        var view = _resolve();
        if (view != null) {
            view.refreshLabels();
            WatchUi.requestUpdate();
        }
    }

    function _resolve() as TileOrderView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as TileOrderView?;
    }

}

class TileOrderDetailDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WeakReference;
    private var _parent as WeakReference;

    function initialize(view as TileOrderDetailMenu, parent as TileOrderDelegate) {
        Menu2InputDelegate.initialize();
        _view = view.weak();
        _parent = parent.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var view = _resolveView();
        if (view == null) {
            return;
        }
        var action = item.getId() as Symbol;
        if (action == :moveUp) {
            TileOrder.moveUp(view.category);
        } else if (action == :moveDown) {
            TileOrder.moveDown(view.category);
        } else if (action == :toggleHidden) {
            TileOrder.toggleHidden(view.category);
        }
        var parent = _resolveParent();
        if (parent != null) {
            parent.refreshView();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function _resolveView() as TileOrderDetailMenu? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as TileOrderDetailMenu?;
    }

    function _resolveParent() as TileOrderDelegate? {
        if (!_parent.stillAlive()) {
            return null;
        }
        return _parent.get() as TileOrderDelegate?;
    }

}
