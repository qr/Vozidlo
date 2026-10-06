import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
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

    private var _carLocation as Position.Location;
    private var _myLocation as Position.Location?;

    function initialize(carLocation as Position.Location, myLocation as Position.Location?) {
        MapView.initialize();
        _carLocation = carLocation;
        _myLocation = myLocation;
    }

    function onLayout(dc as Dc) as Void {
    }

    // Markers, mode and visible area are all (re)built here rather than in
    // initialize(): onShow() is what runs every time this view is
    // actually displayed, so a fresh instance is never missing them.
    function onShow() as Void {
        setMapMode(WatchUi.MAP_MODE_PREVIEW);

        var carMarker = new WatchUi.MapMarker(_carLocation);
        carMarker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
        carMarker.setLabel("Car");
        var markers = [ carMarker ] as Array<WatchUi.MapMarker>;

        var myLocation = _myLocation;
        if (myLocation != null) {
            var myMarker = new WatchUi.MapMarker(myLocation as Position.Location);
            myMarker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
            myMarker.setLabel("You");
            markers.add(myMarker);
        }
        setMapMarker(markers);

        var topLeft = _carLocation.getProjectedLocation(Math.toRadians(315.0d), _PREVIEW_RADIUS_METERS);
        var bottomRight = _carLocation.getProjectedLocation(Math.toRadians(135.0d), _PREVIEW_RADIUS_METERS);
        setMapVisibleArea(topLeft, bottomRight);
    }

    // US-030: release this view's own map state. Every MapMarker and any
    // MapPolyline: the moment it stops being shown, per the task's own
    // instruction to load the map only on request and free it on onHide().
    function onHide() as Void {
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

    private function _resolve() as MapPreviewView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as MapPreviewView?;
    }

}
