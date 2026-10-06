import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/Settings.mc. Built with -t, stripped from release builds
// automatically (Garmin's compiler removes (:test)-annotated code unless -t is
// passed), run via `ciq test` -> monkeydo <prg> <device> /t.
module SettingsTests {

    // Trivial test proving the harness itself: build, sign, load in the simulator,
    // run under /t: is wired up correctly.
    (:test)
    function wiringIsAlive(logger as Logger) as Boolean {
        return 1 + 1 == 2;
    }

    // US-001: a VIN that is not exactly 17 characters must be reported as invalid,
    // before any request is ever made. Real-shaped 17-character VIN, plus the two
    // adjacent boundaries and the empty case.
    (:test)
    function vinValidation(logger as Logger) as Boolean {
        var seventeen = "TMBJJ7NS4H0123456";
        var sixteen = "TMBJJ7NS4H012345";
        var eighteen = "TMBJJ7NS4H01234567";

        if (!Settings.isVinValid(seventeen)) {
            logger.error("a 17-character VIN must be reported as valid");
            return false;
        }
        if (Settings.isVinValid(sixteen)) {
            logger.error("a 16-character VIN must be reported as invalid");
            return false;
        }
        if (Settings.isVinValid(eighteen)) {
            logger.error("an 18-character VIN must be reported as invalid");
            return false;
        }
        if (Settings.isVinValid("")) {
            logger.error("an empty VIN must be reported as invalid");
            return false;
        }
        return true;
    }

}
