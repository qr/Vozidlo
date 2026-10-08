import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/api/Endpoints.mc and the request-options half of
// source/api/ApiClient.mc (US-042, US-053). These are the highest-value tests
// in the project: they cover the exact two URL bugs that have already reached
// the real API and cost a request each: a missing "/vehicles/" segment, and
// a trailing slash before "?include=", plus the :responseType split that
// makes every command response readable at all.
module EndpointTests {

    const VIN = "TMBJJ7NS4H0123456";

    // --------------------------------------------------------------- reads

    (:test)
    function statusReadUrl(logger as Logger) as Boolean {
        var url = Endpoints.vehicle(VIN);
        var expected = "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456";
        if (!url.equals(expected)) {
            logger.error("expected '" + expected + "', got '" + url + "'");
            return false;
        }
        return true;
    }

    (:test)
    function statusReadWithIncludeUrl(logger as Logger) as Boolean {
        var url = Endpoints.vehicleWithInclude(VIN, "status,charging");
        var expected = "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456?include=status,charging";
        if (!url.equals(expected)) {
            logger.error("expected '" + expected + "', got '" + url + "'");
            return false;
        }
        return true;
    }

    // The exact shape of the second shipped bug: a "/" must never appear
    // between the VIN and the "?" that starts a query string.
    (:test)
    function noSlashBeforeQueryString(logger as Logger) as Boolean {
        var url = Endpoints.vehicleWithInclude(VIN, "status");
        var vinIndex = url.find(VIN);
        if (vinIndex == null) {
            logger.error("VIN not found in '" + url + "'");
            return false;
        }
        var vinEnd = vinIndex + VIN.length();
        var nextChar = url.substring(vinEnd, vinEnd + 1);
        if (nextChar == null || !nextChar.equals("?")) {
            logger.error("expected '?' immediately after the VIN, got '" + (nextChar != null ? nextChar : "null") + "' in '" + url + "'");
            return false;
        }
        return true;
    }

    // The exact shape of the first shipped bug: every endpoint must route
    // through "/vehicles/{vin}", never just "/{vin}".
    (:test)
    function everyEndpointHasTheVehiclesSegment(logger as Logger) as Boolean {
        var urls = [
            Endpoints.vehicle(VIN),
            Endpoints.startAirConditioning(VIN),
            Endpoints.stopAirConditioning(VIN),
            Endpoints.startActiveVentilation(VIN),
            Endpoints.stopActiveVentilation(VIN),
            Endpoints.startAuxiliaryHeating(VIN),
            Endpoints.stopAuxiliaryHeating(VIN),
            Endpoints.startCharging(VIN),
            Endpoints.stopCharging(VIN),
            Endpoints.chargingMode(VIN),
            Endpoints.chargingLimit(VIN),
            Endpoints.chargingProfile(VIN, "1")
        ] as Array<String>;
        var needle = "/vehicles/" + VIN;
        for (var i = 0; i < urls.size(); i += 1) {
            if (urls[i].find(needle) == null) {
                logger.error("missing '" + needle + "' in '" + urls[i] + "'");
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------ commands

    (:test)
    function startAirConditioningUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.startAirConditioning(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/air-conditioning/start");
    }

    (:test)
    function stopAirConditioningUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.stopAirConditioning(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/air-conditioning/stop");
    }

    (:test)
    function startActiveVentilationUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.startActiveVentilation(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/active-ventilation/start");
    }

    (:test)
    function stopActiveVentilationUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.stopActiveVentilation(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/active-ventilation/stop");
    }

    (:test)
    function startAuxiliaryHeatingUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.startAuxiliaryHeating(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/auxiliary-heating/start");
    }

    (:test)
    function stopAuxiliaryHeatingUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.stopAuxiliaryHeating(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/auxiliary-heating/stop");
    }

    (:test)
    function startChargingUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.startCharging(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/charging/start");
    }

    (:test)
    function stopChargingUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.stopCharging(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/charging/stop");
    }

    (:test)
    function chargingModeUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.chargingMode(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/charging/mode");
    }

    (:test)
    function chargingLimitUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.chargingLimit(VIN),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/charging/limit");
    }

    (:test)
    function chargingProfileUrl(logger as Logger) as Boolean {
        return _assertEquals(logger, Endpoints.chargingProfile(VIN, "42"),
            "https://public.api.connect.skoda-auto.cz/api/v1/vehicles/TMBJJ7NS4H0123456/charging-profiles/42");
    }

    // ------------------------------------------------------ request options

    // US-042: a read request sets :responseType.
    (:test)
    function readOptionsSetsResponseType(logger as Logger) as Boolean {
        var options = ApiClient.readOptions("key123");
        if (!(options.get(:responseType) == Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON)) {
            logger.error(":responseType must be HTTP_RESPONSE_CONTENT_TYPE_JSON on a read");
            return false;
        }
        if (!(options.get(:method) == Communications.HTTP_REQUEST_METHOD_GET)) {
            logger.error(":method must be GET on a read");
            return false;
        }
        var headers = options.get(:headers) as Dictionary;
        if (!(headers.get("X-API-Key") as String).equals("key123")) {
            logger.error("X-API-Key header not carried through");
            return false;
        }
        return true;
    }

    // US-042: a command request OMITS :responseType entirely, not sets it to
    // null, the key itself must be absent.
    (:test)
    function commandOptionsOmitsResponseType(logger as Logger) as Boolean {
        var options = ApiClient.commandOptions(Communications.HTTP_REQUEST_METHOD_POST, "key123");
        if (options.hasKey(:responseType)) {
            logger.error(":responseType must be entirely absent from command options");
            return false;
        }
        var headers = options.get(:headers) as Dictionary;
        if (!(headers.get("Content-Type") == Communications.REQUEST_CONTENT_TYPE_JSON)) {
            logger.error("Content-Type header must be REQUEST_CONTENT_TYPE_JSON on a command");
            return false;
        }
        return true;
    }

    // US-042: the two option shapes differ exactly as specified, not just in
    // whether :responseType is present, but nowhere else unexpectedly.
    (:test)
    function readAndCommandOptionsDifferOnlyAsSpecified(logger as Logger) as Boolean {
        var read = ApiClient.readOptions("key123");
        var command = ApiClient.commandOptions(Communications.HTTP_REQUEST_METHOD_PUT, "key123");

        if (!read.hasKey(:responseType) || command.hasKey(:responseType)) {
            logger.error("only the read options may carry :responseType");
            return false;
        }
        var commandHeaders = command.get(:headers) as Dictionary;
        var readHeaders = read.get(:headers) as Dictionary;
        if (!commandHeaders.hasKey("Content-Type") || readHeaders.hasKey("Content-Type")) {
            logger.error("only the command options may carry a Content-Type header");
            return false;
        }
        return true;
    }

    function _assertEquals(logger as Logger, actual as String, expected as String) as Boolean {
        if (!actual.equals(expected)) {
            logger.error("expected '" + expected + "', got '" + actual + "'");
            return false;
        }
        return true;
    }

    // A bodiless command still carries a body: `{}`, not null. Garmin
    // Connect on Android drops a JSON POST without one (code 0, nothing
    // sent), so stop climate and both charging commands never left the phone.
    (:test)
    function aBodilessCommandSendsAnEmptyJsonObject(logger as Logger) as Boolean {
        var body = ApiClient.noBody();
        if (body == null || !(body instanceof Dictionary) || body.size() != 0) {
            logger.error("noBody() must be an empty dictionary");
            return false;
        }
        return true;
    }

}
