module Google
  class HTTPRequestFailed < StandardError; end
  class HTTPAuthorizationFailed < StandardError; end
  class HTTPNotFound < StandardError; end
  class HTTPTooManyRedirections < StandardError; end
end