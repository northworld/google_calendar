require 'signet/oauth_2/client'

module Google

  #
  # This is a utility class that communicates with the google calendar api.
  #
  class Connection
    BASE_URI = "https://www.googleapis.com/calendar/v3"
    TOKEN_URI ="https://accounts.google.com/o/oauth2/token"
    AUTH_URI = "https://accounts.google.com/o/oauth2/auth"
    SCOPE = "https://www.googleapis.com/auth/calendar"
    attr_accessor :client

    def self.new_with_service_account(params)
      client = Signet::OAuth2::Client.new(
        :scope => SCOPE,
        :issuer => params[:client_id],
        :audience => TOKEN_URI,
        :token_credential_uri => TOKEN_URI,
        :signing_key => params[:signing_key],
        :person => params[:person]
      )
      Connection.new(params, client)
    end

    #
    # A utility method used to centralize the creation of connections
    #
    def self.factory(params) # :nodoc
      Connection.new(
        :client_id => params[:client_id],
        :client_secret => params[:client_secret],
        :refresh_token => params[:refresh_token],
        :redirect_url => params[:redirect_url],
        :state => params[:state]
      )
    end

    #
    # Prepare a connection to google for fetching a calendar events
    #
    #  the +params+ paramater accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/)
    # * :client_secret => the client secret you received from Google after registering your application with them.
    # * :redirect_uri => the url where your users will be redirected to after they have successfully permitted access to their calendars. Use 'urn:ietf:wg:oauth:2.0:oob' if you are using an 'application'"
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again)
    #
    def initialize(params, client=nil)

      raise ArgumentError unless client || Connection.credentials_provided?(params)

      @client = client || Signet::OAuth2::Client.new(
        :client_id => params[:client_id],
        :client_secret => params[:client_secret],
        :redirect_uri => params[:redirect_url],
        :refresh_token => params[:refresh_token],
        :state => params[:state],
        :authorization_uri => AUTH_URI,
        :token_credential_uri => TOKEN_URI,
        :scope => SCOPE
      )

      # try to get an access token if possible.
      if params[:refresh_token]
        @client.refresh_token = params[:refresh_token]
        @client.grant_type = 'refresh_token'
      end

      if params[:refresh_token] || params[:signing_key]
        Connection.get_new_access_token(@client)
      end

    end

    #
    # The URL you need to send a user in order to let them grant you access to their calendars.
    #
    def authorize_url
      @client.authorization_uri
    end

    #
    # The single use auth code that google uses during the auth process.
    #
    def auth_code
      @client.code
    end

    #
    # The current access token.  Used during a session, typically expires in a hour.
    #
    def access_token
      @client.access_token
    end

    #
    # The refresh token is used to obtain a new access token.  It remains valid until a user revokes access.
    #
    def refresh_token
      @client.refresh_token
    end

    #
    # Convenience method used to streamline the process of logging in with a auth code.
    # Returns the refresh token.
    #
    def login_with_auth_code(auth_code)
      @client.code = auth_code
      Connection.get_new_access_token(@client)
      @client.refresh_token
    end

    #
    # Convenience method used to streamline the process of logging in with a refresh token.
    #
    def login_with_refresh_token(refresh_token)
      @client.refresh_token = refresh_token
      @client.grant_type = 'refresh_token'
      Connection.get_new_access_token(@client)
    end

    #
    # Send a request to google.
    #
    def send(path, method, content = '')

      uri = BASE_URI + path
      response = @client.fetch_protected_resource(
        :uri => uri,
        :method => method,
        :body  => content,
        :headers => {'Content-type' => 'application/json'}
      )

      check_for_errors(response)

      return response
    end

    protected

    #
    # Utility method to centralize the process of getting an access token.
    #
    def self.get_new_access_token(client) #:nodoc:
      begin
        client.fetch_access_token!
      rescue Signet::AuthorizationError
        raise HTTPAuthorizationFailed
      end
    end

    #
    # Check for common HTTP Errors and raise the appropriate response.
    # Note: error 401 (InvalidCredentialsError) is handled by Signet.
    #
    def check_for_errors(response) #:nodoc
      case response.status
        when 400 then raise HTTPRequestFailed, response.body
        when 403 then parse_403_error(response)
        when 404 then raise HTTPNotFound, response.body
        when 409 then raise RequestedIdentifierAlreadyExistsError, response.body
        when 410 then raise GoneError, response.body
        when 412 then raise PreconditionFailedError, response.body
        when 500 then raise BackendError, response.body
      end
    end

    #
    # Utility method to centralize handling of 403 errors.
    #
    def parse_403_error(response)
      case JSON.parse(response.body)["error"]["message"]
        when "Forbidden"                        then raise ForbiddenError, response.body
        when "Daily Limit Exceeded"             then raise DailyLimitExceededError, response.body
        when "User Rate Limit Exceeded"         then raise UserRateLimitExceededError, response.body
        when "Rate Limit Exceeded"              then raise RateLimitExceededError, response.body
        when "Calendar usage limits exceeded."  then raise CalendarUsageLimitExceededError, response.body
        else                                    raise ForbiddenError, response.body
      end      
    end

    #
    # Utility method to centralize credential validation.
    #
    def self.credentials_provided?(params) #:nodoc:
      blank = /[^[:space:]]/
      !(params[:client_id] !~ blank) && !(params[:client_secret] !~ blank)
    end
  end
end
