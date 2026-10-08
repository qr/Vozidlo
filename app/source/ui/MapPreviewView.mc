import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

// US-030/US-031: the map screen, split out of LocationView.mc on purpose.
// map rendering is the one place in this app the 768 KB watch-app budget is
// worth watching (docs/best-practices), so this view's state only exists
// between LocationView.openMap() pushing it and this view's own onHide()
// releasing it. LocationView itself never allocates a MapView.
//
// Modelled directly on the Connect IQ SDK's own MapSample
// (samples/MapSample/source/MapSampleMapView.mc): MAP_MODE_PREVIEW,
// WatchUi.MapMarker for both the car and (when known) the user, and the
// same "back steps BROWSE -> PREVIEW -> pop" delegate shape as
// MapSampleMapDelegate, see MapPreviewDelegate below.
class MapPreviewView extends WatchUi.MapView {

    // A fixed box around the CAR's own location, not a bounding box of both
    // markers: US-030 asks for "centred on the car" specifically, which
    // must hold even when the user's own position (which can be anywhere)
    // is also plotted.
    private const _PREVIEW_RADIUS_METERS = 400.0d;

    // The car's spot, kept for the map's own MENU > "Navigate to car".
    private var _car as Position.Location;

    // Set once the map menu has been opened, so the onHide() calls that the
    // menu and its confirmation trigger do not clear the markers the user
    // returns to; reset when the map itself is left (release()). Not reset
    // in onShow(): the pop of the menu and the push of the confirmation can
    // run back to back, and a reset in between would clear anyway.
    private var _coveredByChild as Boolean = false;

    // Everything the map needs is set up HERE, not in onShow(), and that is
    // load-bearing. Setting the markers, the visible area and the screen
    // area from onShow() throws
    // "UnexpectedTypeException: Screen visible area top left is not set"
    // out of WatchUi.pushView(), and the watch shows the IQ error screen:
    // by the time onShow() runs the view is already being rendered, and the
    // render reads state the constructor was supposed to have left behind.
    // That is how this screen shipped in 1.0.0. The order below is Garmin's
    // own from samples/MapSample/source/MapSampleMapView.mc, including
    // setScreenVisibleArea() last.
    //
    // This view is constructed fresh by LocationView.openMap() on every
    // open and discarded on the pop, so a constructor is as good a place as
    // onShow() for state that must be rebuilt each time.
    function initialize(carLocation as Position.Location, myLocation as Position.Location?) {
        MapView.initialize();

        setMapMode(WatchUi.MAP_MODE_PREVIEW);

        var carMarker = new WatchUi.MapMarker(carLocation);
        carMarker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
        carMarker.setLabel("Car");
        var markers = [ carMarker ] as Array<WatchUi.MapMarker>;

        if (myLocation != null) {
            var myMarker = new WatchUi.MapMarker(myLocation as Position.Location);
            myMarker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
            myMarker.setLabel("You");
            markers.add(myMarker);
        }
        setMapMarker(markers);

        var topLeft = carLocation.getProjectedLocation(Math.toRadians(315.0d), _PREVIEW_RADIUS_METERS);
        var bottomRight = carLocation.getProjectedLocation(Math.toRadians(135.0d), _PREVIEW_RADIUS_METERS);
        setMapVisibleArea(topLeft, bottomRight);

        // The whole screen, where MapSample passes screenHeight / 2: that
        // sample draws a label over the bottom half, and this view draws
        // nothing on top of the map (see the note on onUpdate() below), so
        // nothing is obscured.
        var screen = System.getDeviceSettings();
        setScreenVisibleArea(0, 0, screen.screenWidth, screen.screenHeight);

        // After Garmin's sequence on purpose: a plain field, not map state.
        _car = carLocation;
    }

    function carLocation() as Position.Location {
        return _car;
    }

    // Called by the delegate right before it pushes the map menu.
    function holdForChild() as Void {
        _coveredByChild = true;
    }

    // Called by the delegate right before it pops the map itself.
    function release() as Void {
        _coveredByChild = false;
    }

    function onLayout(dc as Dc) as Void {
    }

    // US-030: release this view's own map state. Every MapMarker and any
    // MapPolyline: the moment it stops being shown, per the task's own
    // instruction to load the map only on request and free it on onHide().
    // Except while the map menu covers it: clear() there would bring the
    // user back from "No" to a map without its Car and You pins, and setting
    // markers again from onShow() is the path that crashed 1.0.0 (see the
    // constructor). The pop out of the map still clears.
    function onHide() as Void {
        if (_coveredByChild) {
            return;
        }
        clear();
    }

    // No onUpdate() override: this view draws nothing of its own on top of
    // the map, so the inherited WatchUi.MapView.onUpdate() already does
    // everything needed. (The SDK's own MapSample calls
    // `MapView.onUpdate(dc)` explicitly from an override, but that symbol is
    // not reachable from application code on this SDK/API level: simply
    // not overriding onUpdate() at all gets the same rendering.)

}

// US-031: pan/zoom (BROWSE) plus the two-step back (BROWSE -> PREVIEW ->
// pop out of the map entirely). This is the one deliberate exception to
// "never remap the back behaviour" (docs/best-practices) in this app: it
// is the exact pattern Garmin's own MapSample ships for a MapView
// (MapSampleMapDelegate.onBack()), not an invention of ours, and it is
// literally what US-031's acceptance criteria ask for.
class MapPreviewDelegate extends WatchUi.BehaviorDelegate {

    // Weak, see docs/best-practices, "Break reference cycles with weak()".
    private var _view as WeakReference;

    function initialize(view as MapPreviewView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onBack() as Boolean {
        var view = _resolve();
        if (view == null) {
            return false;
        }
        if (view.getMapMode() == WatchUi.MAP_MODE_BROWSE) {
            view.setMapMode(WatchUi.MAP_MODE_PREVIEW);
        } else {
            view.release();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }

    // US-031: SELECT switches into BROWSE, matching MapSampleMapDelegate's
    // own choice and this app's existing "SELECT is the direct action"
    // convention.
    function onSelect() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.setMapMode(WatchUi.MAP_MODE_BROWSE);
        }
        return true;
    }

    // B6/research 2026-10-07: the map had no MENU handler, so navigating
    // meant backing out to Find my car first. Same confirmation and
    // CarNavigation path as there (NavigateConfirm).
    function onMenu() as Boolean {
        var view = _resolve();
        if (view == null) {
            return false;
        }
        var car = view.carLocation().toDegrees();
        var menu = new NightMenu("Map", 0, null);
        menu.addItem(new NightMenuItem(:navigate, "Navigate to car", null, :pin, null));
        view.holdForChild();
        WatchUi.pushView(menu, new MapMenuDelegate(car[0], car[1]), Theme.SLIDE_IN);
        return true;
    }

    private function _resolve() as MapPreviewView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as MapPreviewView?;
    }

}

// MENU on the map (PoC NF.MAP_MENU): one item. Pops first, so the
// confirmation lands on the map and "No" returns to it (A14).
class MapMenuDelegate extends NightMenuDelegate {

    private var _latitude as Double;
    private var _longitude as Double;

    function initialize(latitude as Double, longitude as Double) {
        NightMenuDelegate.initialize(true);
        _latitude = latitude;
        _longitude = longitude;
    }

    function onPick(id as Object?) as Void {
        if (id == :navigate) {
            NavigateConfirm.push(_latitude, _longitude);
        }
    }

}
