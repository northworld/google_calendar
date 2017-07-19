module Google
  # Signet::AuthorizationError
  # Not part of Google Calendar API Errors
  class HTTPAuthorizationFailed < StandardError; end

  # Google Calendar API Errors per documentation
  # https://developers.google.com/google-apps/calendar/v3/errors
  
  # 400: Bad Request
  #
  # User error. This can mean that a required field or parameter has not been
  # provided, the value supplied is invalid, or the combination of provided
  # fields is invalid.
  class HTTPRequestFailed < StandardError; end

  # 401: Invalid Credentials
  #
  # Invalid authorization header. The access token you're using is either
  # expired or invalid.
  class InvalidCredentialsError < StandardError; end

  # 403: Daily Limit Exceeded
  #
  # The Courtesy API limit for your project has been reached.
  class DailyLimitExceededError < StandardError; end

  # 403: User Rate Limit Exceeded
  #
  # The per-user limit from the Developer Console has been reached.
  class UserRateLimitExceededError < StandardError; end
  
  # 403: Rate Limit Exceeded
  #
  # The user has reached Google Calendar API's maximum request rate per
  # calendar or per authenticated user.
  class RateLimitExceededError < StandardError; end

  # 403: Calendar usage limits exceeded
  #
  # The user reached one of the Google Calendar limits in place to protect
  # Google users and infrastructure from abusive behavior.
  class CalendarUsageLimitExceededError < StandardError; end

  # 404: Not Found
  #
  # The specified resource was not found.
  class HTTPNotFound < StandardError; end

  # 409: The requested identifier already exists
  #
  # An instance with the given ID already exists in the storage.
  class RequestedIdentifierAlreadyExistsError < StandardError; end

  # 410: Gone
  #
  # SyncToken or updatedMin parameters are no longer valid. This error can also
  # occur if a request attempts to delete an event that has already been
  # deleted.
  class GoneError < StandardError; end

  # 412: Precondition Failed
  #
  # The etag supplied in the If-match header no longer corresponds to the
  # current etag of the resource.
  class PreconditionFailedError < StandardError; end

  # 500: Backend Error
  #
  # An unexpected error occurred while processing the request.
  class BackendError < StandardError; end

  #
  # 403: Forbidden Error
  #
  # User has no authority to conduct the requested operation on the resource.
  # This is not a part of official Google Calendar API Errors documentation.
  class ForbiddenError < StandardError; end
end
