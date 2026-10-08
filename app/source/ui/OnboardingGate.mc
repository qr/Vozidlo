import Toybox.Lang;
import Toybox.WatchUi;

// The app's entry gate (US-002, US-003, US-004): decides which onboarding
// screen, if any, stands between "the app started" and whatever the rest of
// the app shows normally. Kept out of VozidloApp.mc so getInitialView() stays
// a one-line, easily reviewed hook: all the actual policy lives here, in a
// file this task owns outright, rather than growing inside the shared entry
// point another task also touches.
module Onboarding {

    // VozidloApp.getInitialView() calls this first. Three independent reasons
    // to intercept, checked in the order a user would actually hit them:
    //   1. No key, or a syntactically invalid VIN: US-003, never a
    //      request.
    //   2. A syntactically valid key that has never had a successful
    //      request: US-002's "on first request" validation belongs here,
    //      once, rather than scattered across every screen that might
    //      otherwise make the first one.
    //   3. A key that HAS validated before, but is old enough that the
    //      159-day estimate says it is probably close to expiring: US-004's
    //      non-blocking notice, shown once per launch rather than nagging
    //      on every redraw.
    // Returns null when none of these apply, meaning "fall through to
    // whatever the app shows today."
    function gateView(settings as Settings.Config) as WatchUi.View? {
        if (!isConfigured(settings)) {
            return new OnboardingView(false);
        }
        if (!KeyLifetime.hasValidated(settings.apiKey)) {
            return new OnboardingView(true);
        }
        if (KeyLifetime.isEstimatedNearExpiry(settings.apiKey)) {
            return new OnboardingExpiryNoticeView();
        }
        return null;
    }

    // US-003's precondition: a key must be present and the VIN must pass
    // Settings.isVinValid() (already computed onto Config.vinValid) before
    // the app ever attempts a request.
    function isConfigured(settings as Settings.Config) as Boolean {
        return settings.apiKey.length() > 0 && settings.vinValid;
    }

    // Whether OnboardingView.onShow() starts the validating request: only
    // in validating mode, never over a failure waiting for its manual retry
    // (US-002 "never retry automatically"), and never while one is already
    // on its way (onShow() fires again after anything pushed on top pops).
    function shouldValidate(validating as Boolean, hasTransientError as Boolean, inFlight as Boolean) as Boolean {
        return validating && !hasTransientError && !inFlight;
    }

    // US-002: maps the outcome of the validation request to the specific
    // onboarding screen its cause names, or null when the failure isn't one
    // of onboarding's four distinguished causes: the caller falls back to
    // its own generic handling (see ProblemDetail.describe()) for anything
    // else, e.g. quota exhaustion or a 5xx.
    //
    // Takes the raw (status, body) rather than a ProblemDetail.Message
    // because the exact expiry date this screen must show only exists in
    // the raw `detail` string: ProblemDetail's own message text is already
    // a step removed from it. ProblemDetail.describe() is still used below
    // for the wording of the other three causes, so there is exactly one
    // place that wording is written.
    function viewForProblem(status as Number, body as Dictionary?) as WatchUi.View? {
        var message = ProblemDetail.describe(status, body, null);
        var type = message.problemType;
        var detail = (body != null) ? body.get("detail") as String? : null;

        if (ProblemDetail.typeIs(type, "api-key-expired")) {
            return new OnboardingBlockedView(_expiredText(detail));
        }
        if (ProblemDetail.typeIs(type, "api-key-not-authorized")) {
            return new OnboardingBlockedView(_withInstructions(message.text));
        }
        if (ProblemDetail.typeIs(type, "about:blank") && detail != null) {
            if (detail.find("No vehicle found") == 0) {
                return new OnboardingBlockedView(_withInstructions(message.text));
            }
            if (detail.find("No static resource") == 0) {
                // US-002's other 404, and the whole reason this
                // distinction exists: this is OUR bug, not the user's VIN.
                // There is nothing they can do about it, so: deliberately
                //: no "create a new key" instructions are appended here;
                // doing so would misdirect the user toward fixing something
                // that was never broken. See docs/requirements.md US-002 and
                // implementation notes.
                return new OnboardingBlockedView(message.text);
            }
        }
        return null;
    }

    // US-004: "with the same instructions as the unconfigured state".
    // literally the same string OnboardingView(false) shows, not a
    // paraphrase, so the two screens can never quietly drift apart.
    function _withInstructions(text as String) as String {
        return text + " " + (WatchUi.loadResource(Rez.Strings.OnboardingGuidanceMessage) as String);
    }

    function _expiredText(detail as String?) as String {
        var date = KeyLifetime.parseExpiredDetailDate(detail);
        var head;
        if (date != null) {
            head = (WatchUi.loadResource(Rez.Strings.OnboardingKeyExpiredPrefix) as String) + date + ".";
        } else {
            // The sentence shape didn't match what we parse for: still
            // tell the truth (the key expired), just without a date we
            // can't actually vouch for.
            head = WatchUi.loadResource(Rez.Strings.OnboardingKeyExpiredFallback) as String;
        }
        return _withInstructions(head);
    }

}
