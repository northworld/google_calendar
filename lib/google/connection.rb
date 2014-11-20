require 'signet/oauth_2/client'
require "addressable/uri"

module Google

  #
  # This is a utility class that communicates with the google calendar api.
  #
  class Connection
    BASE_URI = "https://www.googleapis.com/calendar/v3"

    attr_accessor :client

    #
    # Prepare a connection to google for fetching a calendar events
    #
    #  the +params+ paramater accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/)
    # * :client_secret => the client secret you received from Google after registering your application with them.
    # * :redirect_uri => the url where your users will be redirected to after they have successfully permitted access to their calendars. Use 'urn:ietf:wg:oauth:2.0:oob' if you are using an 'application'"
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again)
    #
    def initialize(params)

      raise ArgumentError unless Connection.credentials_provided?(params)

      @client = Signet::OAuth2::Client.new(
        :client_id => params[:client_id],
        :client_secret => params[:client_secret],
        :redirect_uri => params[:redirect_url],
        :refresh_token => params[:refresh_token],
        :authorization_uri => 'https://accounts.google.com/o/oauth2/auth',
        :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
        :scope => "https://www.googleapis.com/auth/calendar"
      )

      calendar_id = params[:calendar_id]

      # raise CalenarIDMissing unless calendar_id
      @events_url = "#{BASE_URI}/calendars/#{CGI::escape calendar_id}/events"

      # try to get an access token if possible.
      if params[:refresh_token]
        @client.refresh_token = params[:refresh_token]
        @client.grant_type = 'refresh_token'
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
    def send(uri, method, content = '')

      response = @client.fetch_protected_resource(
        :uri => uri,
        :method => method,
        :body  => content,
        :headers => {'Content-type' => 'application/json'}
      )

      check_for_errors(response)

      return response
    end

    #
    # Wraps the `send` method. Send an event related request to Google.
    #
    def send_events_request(path_and_query_string, method, content = '')
      send(Addressable::URI.parse(@events_url + path_and_query_string), method, content)
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
    #
    def check_for_errors(response) #:nodoc
      case response.status
        when 400 then raise HTTPRequestFailed, response.body
        when 404 then raise HTTPNotFound, response.body
      end
    end

    private

    #
    # 
    #
    def self.credentials_provided?(params) #:nodoc:
      blank = /[^[:space:]]/
      !(params[:client_id] !~ blank) && !(params[:client_secret] !~ blank)
    end

  end
end
