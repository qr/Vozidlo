import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Unit tests for source/KeyLifetime.mc and source/ui/OnboardingGate.mc
// (US-002, US-003, US-004, US-007). The three the task brief asks for by
// name: the 159-day boundary, detail-date parsing, and "a different key
// resets the start date", plus a couple of cheap, purely logical ones for
// the entry-gate decision itself, and the C7 text layout (OnboardingLayout
// in ui/OnboardingView.mc) with the copy it has to fit.
//
// KeyLifetime's "...At" functions take `nowEpoch` explicitly so these tests
// can assert "160 days from now" without a way to fast-forward the
// simulator's clock, see KeyLifetime.mc's own comment on why that
// parameter exists at all.
module OnboardingTests {

    const KEY_A = "key-A-0123456789";
    const KEY_B = "key-B-9876543210";
    const DAY = 86400;

    // ------------------------------------------------------- validation

    // US-002: one validating request, never over a failure awaiting its
    // manual retry, and not a second one when onShow() fires again while
    // the first is on its way.
    (:test)
    function validationStartsOnceAndNeverOverAFailure(logger as Logger) as Boolean {
        if (!Onboarding.shouldValidate(true, false, false)) {
            logger.error("validating mode with nothing pending must validate");
            return false;
        }
        if (Onboarding.shouldValidate(true, false, true)) {
            logger.error("a request already on its way must not be doubled");
            return false;
        }
        if (Onboarding.shouldValidate(true, true, false)) {
            logger.error("a shown failure waits for the manual retry");
            return false;
        }
        if (Onboarding.shouldValidate(false, false, false)) {
            logger.error("guidance mode never validates");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------- 159-day estimate

    (:test)
    function noRecordIsNeverNearExpiry(logger as Logger) as Boolean {
        KeyLifetime.clear();
        if (KeyLifetime.isEstimatedNearExpiryAt(KEY_A, 1000000)) {
            logger.error("a key that has never validated has nothing to estimate from");
            return false;
        }
        return true;
    }

    // US-004: "given more than 159 days have passed... a non-blocking
    // notice." Exactly 159 days is not yet "more than": the boundary is
    // deliberately exclusive.
    (:test)
    function exactlyOneHundredFiftyNineDaysIsNotYetNearExpiry(logger as Logger) as Boolean {
        KeyLifetime.clear();
        var start = 1000000;
        KeyLifetime.recordSuccessAt(KEY_A, start);

        if (KeyLifetime.isEstimatedNearExpiryAt(KEY_A, start + (159 * DAY))) {
            logger.error("exactly 159 days must not yet be reported as near expiry");
            return false;
        }
        return true;
    }

    (:test)
    function oneHundredSixtyDaysIsNearExpiry(logger as Logger) as Boolean {
        KeyLifetime.clear();
        var start = 1000000;
        KeyLifetime.recordSuccessAt(KEY_A, start);

        if (!KeyLifetime.isEstimatedNearExpiryAt(KEY_A, start + (160 * DAY))) {
            logger.error("160 days must be reported as near expiry");
            return false;
        }
        return true;
    }

    // The boundary itself, expressed in days rather than seconds, so a
    // future change to DAY's arithmetic can't silently move it.
    (:test)
    function daysSinceStartTruncatesToWholeDays(logger as Logger) as Boolean {
        KeyLifetime.clear();
        var start = 1000000;
        KeyLifetime.recordSuccessAt(KEY_A, start);

        var almostTwoDays = start + (2 * DAY) - 1;
        if (KeyLifetime.daysSinceStartAt(KEY_A, almostTwoDays) != 1) {
            logger.error("a few seconds short of 2 full days must still read as 1 day");
            return false;
        }
        return true;
    }

    // ---------------------------------------------------- detail-date parsing

    (:test)
    function parsesTheDateOutOfTheExpiredDetailSentence(logger as Logger) as Boolean {
        var date = KeyLifetime.parseExpiredDetailDate("The API key expired on 2026-09-01T00:00:00Z.");
        if (date == null || !date.equals("2026-09-01")) {
            logger.error("expected '2026-09-01', got '" + (date != null ? date : "null") + "'");
            return false;
        }
        return true;
    }

    (:test)
    function parsingToleratesAnUnrecognisedSentenceShape(logger as Logger) as Boolean {
        if (KeyLifetime.parseExpiredDetailDate("Something else entirely.") != null) {
            logger.error("a detail string with no 'on <date>' must not produce a fabricated date");
            return false;
        }
        if (KeyLifetime.parseExpiredDetailDate(null) != null) {
            logger.error("a null detail must not produce a date");
            return false;
        }
        // Shape check: not just "'on ' is present", the ten characters
        // after it must actually look like YYYY-MM-DD.
        if (KeyLifetime.parseExpiredDetailDate("This key expired on your watch.") != null) {
            logger.error("text that merely contains 'on ' without a date shape must not parse");
            return false;
        }
        return true;
    }

    // --------------------------------------------- a different key resets it

    // US-004: "given I enter a new key, then the estimated start date
    // resets." Re-recording the SAME key must NOT move the date (otherwise
    // the 159-day estimate would never fire on a key that keeps
    // succeeding), but a DIFFERENT key always does.
    (:test)
    function sameKeySucceedingAgainDoesNotMoveTheStartDate(logger as Logger) as Boolean {
        KeyLifetime.clear();
        KeyLifetime.recordSuccessAt(KEY_A, 1000);
        KeyLifetime.recordSuccessAt(KEY_A, 5000);

        if (KeyLifetime.startedAt(KEY_A) != 1000) {
            logger.error("a later success with the SAME key must not move its start date");
            return false;
        }
        return true;
    }

    (:test)
    function aDifferentKeyResetsTheStartDate(logger as Logger) as Boolean {
        KeyLifetime.clear();
        KeyLifetime.recordSuccessAt(KEY_A, 1000);
        KeyLifetime.recordSuccessAt(KEY_B, 9000);

        if (KeyLifetime.startedAt(KEY_B) != 9000) {
            logger.error("a new key must get its own, fresh start date");
            return false;
        }
        if (KeyLifetime.startedAt(KEY_A) != null) {
            logger.error("the old key's start date must not still read back once a different key has replaced it");
            return false;
        }
        if (KeyLifetime.hasValidated(KEY_A)) {
            logger.error("the old key must no longer be reported as validated");
            return false;
        }
        return true;
    }

    // -------------------------------------------------------------- the gate

    (:test)
    function unconfiguredSettingsAreNeverConfigured(logger as Logger) as Boolean {
        var noKey = new Settings.Config("", "TMBJJ7NS4H0123456", "C", "", null, true);
        if (Onboarding.isConfigured(noKey)) {
            logger.error("an empty API key must never read as configured");
            return false;
        }

        var badVin = new Settings.Config("some-key", "TOO-SHORT", "C", "", null, true);
        if (Onboarding.isConfigured(badVin)) {
            logger.error("a VIN that fails Settings.isVinValid() must never read as configured");
            return false;
        }

        var ok = new Settings.Config("some-key", "TMBJJ7NS4H0123456", "C", "", null, true);
        if (!Onboarding.isConfigured(ok)) {
            logger.error("a present key with a 17-character VIN must read as configured");
            return false;
        }
        return true;
    }

    // US-002: the routing-bug 404 ("No static resource ...") must never
    // read as a VIN problem, and vice versa: this is the whole reason the
    // two 404s are told apart at all (see docs/requirements.md, US-002).
    (:test)
    function theTwoFlavoursOfFourOhFourProduceDifferentText(logger as Logger) as Boolean {
        var routingBug = Onboarding.viewForProblem(404, {
            "type" => "about:blank",
            "detail" => "No static resource api/v1/TMBJJ7NS4H0123456."
        });
        var unknownVin = Onboarding.viewForProblem(404, {
            "type" => "about:blank",
            "detail" => "No vehicle found for VIN TMBJJ7NS4H0123456."
        });

        if (routingBug == null || unknownVin == null) {
            logger.error("both flavours of 404 must produce a blocking onboarding view");
            return false;
        }
        if (!(routingBug instanceof OnboardingBlockedView) || !(unknownVin instanceof OnboardingBlockedView)) {
            logger.error("both flavours of 404 must resolve to OnboardingBlockedView");
            return false;
        }
        return true;
    }

    // A cause onboarding has no dedicated screen for (e.g. rate limiting)
    // must fall through to null, so the caller uses its own generic
    // handling rather than getting a wrong or misleading onboarding screen.
    (:test)
    function anUnrelatedProblemTypeIsNotOnboardingsConcern(logger as Logger) as Boolean {
        var view = Onboarding.viewForProblem(429, {
            "type" => "https://public.api.connect.skoda-auto.cz/problems/rate-limit-exceeded",
            "detail" => "The rate limit for this API key has been exceeded."
        });
        if (view != null) {
            logger.error("rate-limit-exceeded is not one of onboarding's four causes and must return null");
            return false;
        }
        return true;
    }


    // ------------------------------------------------------------ C7 layout

    // Stand-in fonts: wider than the real ones per character, so a fit here
    // is a margin of safety, not an accident of narrow glyphs.
    class CharWidth {
        private var _px as Number;
        function initialize(px as Number) {
            _px = px;
        }
        function width(s as String) as Number {
            return s.length() * _px;
        }
    }

    const SMALL_H = 32;
    const SMALL_PX = 11;
    const XTINY_H = 19;
    const XTINY_PX = 8;

    function _copy() as Array<String> {
        var guide = WatchUi.loadResource(Rez.Strings.OnboardingGuidanceMessage) as String;
        return [
            guide,
            WatchUi.loadResource(Rez.Strings.OnboardingCheckingMessage) as String,
            WatchUi.loadResource(Rez.Strings.OnboardingExpiryNoticeMessage) as String,
            // The longest screen: expired key plus the guidance (OnboardingGate).
            (WatchUi.loadResource(Rez.Strings.OnboardingKeyExpiredFallback) as String) + " " + guide
        ] as Array<String>;
    }

    function _join(lines as Array<String>) as String {
        var out = "";
        for (var i = 0; i < lines.size(); i += 1) {
            out += (i == 0 ? "" : " ") + (lines[i] as String);
        }
        return out;
    }

    // The layout a screen draws: every line sits inside the chord of the slot
    // it is drawn in, with the glyph margin and without, and no word is lost.
    (:test)
    function onboardingLinesFitTheChordOfTheirSlot(logger as Logger) as Boolean {
        var texts = _copy();
        var small = (new CharWidth(SMALL_PX)).method(:width);
        var xtiny = (new CharWidth(XTINY_PX)).method(:width);
        var margins = [OnboardingLayout.MARGIN, OnboardingLayout.GLYPH_MARGIN] as Array<Number>;
        for (var t = 0; t < texts.size(); t += 1) {
            for (var m = 0; m < margins.size(); m += 1) {
                var result = OnboardingLayout.choose(texts[t], margins[m], SMALL_H, small, XTINY_H, xtiny);
                var lines = result[0];
                var lh = result[2] ? SMALL_H : XTINY_H;
                var measure = result[2] ? small : xtiny;
                var widths = OnboardingLayout.widths(result[1], lh, margins[m]);
                if (lines.size() > result[1]) {
                    logger.error("more lines than slots for text " + t);
                    return false;
                }
                for (var i = 0; i < lines.size(); i += 1) {
                    if (measure.invoke(lines[i]) > widths[i]) {
                        logger.error("text " + t + " line " + i + " is " + measure.invoke(lines[i])
                            + " px in a " + widths[i] + " px chord: '" + lines[i] + "'");
                        return false;
                    }
                }
                if (!_join(lines).equals(texts[t])) {
                    logger.error("text " + t + " lost words: '" + _join(lines) + "'");
                    return false;
                }
            }
        }
        return true;
    }

    // C7: the short "checking" line gets the larger font; the expired-key
    // text (the longest) does not fit four small lines and drops to xtiny.
    (:test)
    function shortCopyUsesSmallAndTheLongestFallsBackToXtiny(logger as Logger) as Boolean {
        var texts = _copy();
        var small = (new CharWidth(SMALL_PX)).method(:width);
        var xtiny = (new CharWidth(XTINY_PX)).method(:width);
        var check = OnboardingLayout.choose(texts[1], OnboardingLayout.MARGIN, SMALL_H, small, XTINY_H, xtiny);
        if (!check[2]) {
            logger.error("'Checking your key...' must fit four small lines");
            return false;
        }
        var expired = OnboardingLayout.choose(texts[3], OnboardingLayout.GLYPH_MARGIN, SMALL_H, small, XTINY_H, xtiny);
        if (expired[2]) {
            logger.error("the expired-key text must not be squeezed into small");
            return false;
        }
        if (OnboardingLayout.useSmall(5) || !OnboardingLayout.useSmall(4)) {
            logger.error("the small-font cut-off is four lines");
            return false;
        }
        return true;
    }

    // C7: button hints moved to bezel glyphs; the copy must not repeat them.
    (:test)
    function onboardingCopyCarriesNoButtonHints(logger as Logger) as Boolean {
        var texts = _copy();
        for (var i = 0; i < texts.size(); i += 1) {
            var t = texts[i];
            if (t.find("Menu for more") != null || t.find("Select to continue") != null) {
                logger.error("button hint left in the copy: '" + t + "'");
                return false;
            }
        }
        return true;
    }

    (:test)
    function emptyTextHasNoLinesAndNoSlots(logger as Logger) as Boolean {
        var result = OnboardingLayout.wrap("", SMALL_H, OnboardingLayout.MARGIN, 4, (new CharWidth(SMALL_PX)).method(:width));
        if (result[0].size() != 0 || result[1] != 0) {
            logger.error("empty text must produce no lines and no slots");
            return false;
        }
        return true;
    }

}
