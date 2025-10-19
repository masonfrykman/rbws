/// Defines ease-of-use shortcuts for the different HTTP status codes as defined in [RTF 9110](https://www.rfc-editor.org/rfc/rfc9110.html)
class HTTPStatusCode {
  // 1XX is not included bc the package user doesn't oversee these things.
  // 2XX - Successful
  static int ok = 200;
  static int created = 201;
  static int accepted = 202;
  static int nonAuthoritativeInformation = 203;
  static int noContent = 204;
  static int resetContent = 205;
  static int partialContent = 206;

  // 3XX - Redirection
  static int multipleChoices = 300;
  static int movedPermanently = 301;
  static int found = 302;
  static int seeOther = 303;
  static int notModified = 304;
  static int useProxy = 305;
  static int temporaryRedirect = 307;
  static int permanentRedirect = 308;

  // 4XX - Client Error
  static int badRequest = 400;
  static int unauthorized = 401;
  static int paymentRequired = 402;
  static int forbidden = 403;
  static int notFound = 404;
  static int methodNotAllowed = 405;
  static int notAcceptable = 406;
  static int proxyAuthenticationRequired = 407;
  static int requestTimeout = 408;
  static int conflict = 409;
  static int gone = 410;
  static int lengthRequired = 411;
  static int preconditionFailed = 412;
  static int contentTooLarge = 413;
  static int uriTooLong = 414;
  static int unsupportedMediaType = 415;
  static int rangeNotSatisfiable = 416;
  static int expectationFailed = 417;
  static int isTeapot = 418;
  static int misdirectedRequest = 421;
  static int unprocessableContent = 422;
  static int upgradeRequired = 426;

  // 5XX - Server Error
  static int internalServerError = 500;
  static int notImplemented = 501;
  static int badGateway = 502;
  static int serviceUnavailable = 503;
  static int gatewayTimeout = 504;
}
