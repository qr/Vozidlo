import Toybox.Lang;

// One age format for every screen (US-009, A17, B4): "Just now", "5 min",
// "2 h", "3 d", with "ago" only on age lines. Replaces the four variants the
// views carried. Each API section ages separately (decisions.md "Data is not
// live"), so callers pass one section's capture time, never a global one.
//
// (:glance) because the glance shows the same age as the app.
(:glance)
module Age {

    const JUST_NOW = "Just now";
    // US-009: older than an hour is stale; shape ("!") plus amber colour.
    const STALE_AFTER = 3600;

    // Phone and car clocks disagree; a capture time in the future is treated
    // as "now" rather than shown as a negative age.
    function elapsed(capturedAt as Number?, now as Number) as Number? {
        if (capturedAt == null) {
            return null;
        }
        var d = now - capturedAt;
        return d < 0 ? 0 : d;
    }

    // Chip and glance form: no "ago", so it fits a 20 px pill.
    function short(seconds as Number) as String {
        if (seconds < 60) {
            return JUST_NOW;
        }
        if (seconds < 3600) {
            return (seconds / 60).toString() + " min";
        }
        if (seconds < 86400) {
            return (seconds / 3600).toString() + " h";
        }
        return (seconds / 86400).toString() + " d";
    }

    // Age-line form; "Just now ago" would read wrong, so that one stays bare.
    function text(seconds as Number) as String {
        var s = short(seconds);
        if (seconds < 60) {
            return s;
        }
        return s + " ago";
    }

    // US-009: exactly one hour is still fresh; the amber style starts after.
    function isStale(seconds as Number) as Boolean {
        return seconds > STALE_AFTER;
    }

    // The status line under a hero: "No data" when nothing was ever cached,
    // "! " in front when stale so the warning survives the monochrome test.
    function line(seconds as Number?) as String {
        if (seconds == null) {
            return "No data";
        }
        if (isStale(seconds)) {
            return "! " + text(seconds);
        }
        return text(seconds);
    }

}
