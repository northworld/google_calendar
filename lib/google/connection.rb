require 'signet/oauth_2/client'
require "addressable/uri"

module Google

  # This is a utility class that performs communication with the google calendar api.
  #
  class Connection
    BASE_URI = "https://www.googleapis.com/calendar/v3"

    attr_accessor :client

    # Prepare an unauthenticated connection to google for fetching a public calendar events
    # calendar_id: the id of the calendar you would like to work with (e.g. en.singapore#holiday@group.v.calendar.google.com)
    def initialize(params)

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
        @client.fetch_access_token!
      end

    end

    def authorize_url
      @client.authorization_uri
    end

    def auth_code
      @client.code
    end

    def access_token
      @client.access_token
    end

    def refresh_token
      @client.refresh_token
    end

    def login_with_auth_code(auth_code)
      @client.code = auth_code
      @client.fetch_access_token!
      @client.refresh_token
    end

    def login_with_refresh_token(refresh_token)
      @client.refresh_token = refresh_token
      @client.grant_type = 'refresh_token'
      @client.fetch_access_token!
    end

    # send a request to google.
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

    # wraps `send` method. send a event related request to google.
    #
    def send_events_request(path_and_query_string, method, content = '')
      send(Addressable::URI.parse(@events_url + path_and_query_string), method, content)
    end

    protected

    # Check for common HTTP Errors and raise the appropriate response.
    #
    def check_for_errors(response) #:nodoc
      case response.status
        when 400 then raise HTTPRequestFailed, response.body
        when 403 then raise HTTPAuthorizationFailed, response.body
        when 404 then raise HTTPNotFound, response.body
      end
    end

    private

    def self.credentials_provided? username, password
      blank = /[^[:space:]]/
      !(username !~ blank) && !(password !~ blank)
    end

  end
end
