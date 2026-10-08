import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Own pager for the status pages (D7: page dots instead of the native
// ViewLoop arc). Holds the model, the visible pages and the current index;
// each page change swaps in a fresh StatusPageView with a native slide.
//
// Ownership: the page view and its delegate hold the pager; the pager holds
// neither, and the model never holds the pager (it bumps a version the pager
// reads instead), so there is no cycle to break.
class StatusPager {

    // switchToView per page gives the native slide. false falls back to one
    // view that only redraws, should switching views per page misbehave on
    // a watch.
    const SWITCH_VIEWS = true;
    // Next page rises from below like the status screen itself; previous
    // and BACK mirror it (B6). Theme names, so this file (which also holds a
    // menu delegate) carries no vertical slide literal.
    const SLIDE_NEXT = Theme.SLIDE_STATUS;
    const SLIDE_PREV = Theme.SLIDE_CHARGING;

    private var _model as StatusModel;
    private var _keys as Array<String>;
    private var _index as Number = 0;
    private var _seenVersion as Number = -1;
    private var _page as StatusPages.Page?;
    private var _pageBuilt as Boolean = false;

    // startKey picks the first page when it is visible (home opens the lock
    // page); otherwise the first visible page.
    function initialize(startKey as String) {
        _model = new StatusModel();
        _model.load();
        _keys = StatusPages.visibleKeys(_model.vehicle());
        _seenVersion = _model.version();
        var i = _keys.indexOf(startKey);
        _index = i >= 0 ? i : 0;
    }

    function model() as StatusModel {
        return _model;
    }

    function index() as Number {
        return _index;
    }

    function count() as Number {
        return _keys.size();
    }

    function currentKey() as String {
        return _keys[_index] as String;
    }

    // Recomputes the pages when the model has new data (a refresh landed),
    // and the current Page when it or the index changed. Cheap when nothing
    // changed, so the views call it from onShow and onUpdate.
    function sync() as Void {
        _model.load();
        var v = _model.version();
        if (v != _seenVersion) {
            _seenVersion = v;
            _keys = StatusPages.visibleKeys(_model.vehicle());
            // As before: an index past the end (a page went away) starts over.
            if (_index >= _keys.size()) {
                _index = 0;
            }
            _pageBuilt = false;
        }
        if (!_pageBuilt) {
            var key = currentKey();
            _page = StatusPages.build(key, StatusPages.sectionFor(_model.vehicle(), key));
            _pageBuilt = true;
        }
    }

    function page() as StatusPages.Page {
        sync();
        return _page as StatusPages.Page;
    }

    // UP/DOWN and swipes page with wrap (B1.3).
    function next() as Void {
        _go((_index + 1) % _keys.size(), SLIDE_NEXT);
    }

    function previous() as Void {
        _go((_index - 1 + _keys.size()) % _keys.size(), SLIDE_PREV);
    }

    function _go(index as Number, slide as WatchUi.SlideType) as Void {
        if (_keys.size() <= 1) {
            return;
        }
        _index = index;
        _pageBuilt = false;
        if (SWITCH_VIEWS) {
            WatchUi.switchToView(new StatusPageView(self), new StatusPageDelegate(self), slide);
        } else {
            WatchUi.requestUpdate();
        }
    }

    function back() as Void {
        WatchUi.popView(SLIDE_PREV);
    }

    // D4: START opens the action list with Refresh first (quota friction,
    // same on every page); the charging page adds the charging screen (D2).
    function openActions() as Void {
        var menu = new NightMenu("Actions", 0, null);
        menu.addItem(new NightMenuItem(:refresh, "Refresh", null, :refresh, null));
        if (currentKey().equals("charging")) {
            menu.addItem(new NightMenuItem(:chargingDetails, "Charging details", null, :bolt, null));
        }
        WatchUi.pushView(menu, new StatusActionDelegate(self), Theme.SLIDE_IN);
    }

    // Refresh with the reason toasted when nothing was sent (US-012,
    // US-013, US-045), since the menu has already closed by now.
    function refresh() as Void {
        Refusal.toast(Refusal.text(_model.refresh(), Quota.secondsUntilReset()));
        WatchUi.requestUpdate();
    }

}

// The page on screen: draws whatever the pager's current page is, so the
// fallback (SWITCH_VIEWS false) can reuse one instance.
class StatusPageView extends WatchUi.View {

    private var _pager as StatusPager;

    function initialize(pager as StatusPager) {
        View.initialize();
        _pager = pager;
    }

    function pager() as StatusPager {
        return _pager;
    }

    // Monochrome flag cached per onShow (A21); a pop back from the menu or
    // the charging screen picks up new data here.
    function onShow() as Void {
        Theme.refresh();
        _pager.sync();
    }

    function onUpdate(dc as Dc) as Void {
        StatusPages.draw(dc, _pager.page(), _pager.index(), _pager.count(), _pager.model().statusLine());
    }

}

// BehaviorDelegate so buttons and swipes map to the same page events.
class StatusPageDelegate extends WatchUi.BehaviorDelegate {

    private var _pager as StatusPager;

    function initialize(pager as StatusPager) {
        BehaviorDelegate.initialize();
        _pager = pager;
    }

    function onNextPage() as Boolean {
        _pager.next();
        return true;
    }

    function onPreviousPage() as Boolean {
        _pager.previous();
        return true;
    }

    function onSelect() as Boolean {
        _pager.openActions();
        return true;
    }

    // A15: a tap must not refresh (or open anything); refresh only via START
    // and the action list. Consuming the tap keeps it from becoming onSelect.
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return true;
    }

    // Back to home, sliding down as the mirror of the way in.
    function onBack() as Boolean {
        _pager.back();
        return true;
    }

}

// The status action list. Pops before onPick (NightMenuDelegate), so a toast
// or the charging screen lands over the status page, not over the menu.
class StatusActionDelegate extends NightMenuDelegate {

    // The pager lives as long as the page view under this menu; weak so the
    // menu never keeps it alive on its own.
    private var _pager as WeakReference;

    function initialize(pager as StatusPager) {
        NightMenuDelegate.initialize(true);
        _pager = pager.weak();
    }

    function onPick(id as Object?) as Void {
        if (id == :chargingDetails) {
            ChargingScreen.open();
            return;
        }
        if (id == :refresh) {
            var pager = _pager.get() as StatusPager?;
            if (pager != null) {
                pager.refresh();
            }
        }
    }

}
