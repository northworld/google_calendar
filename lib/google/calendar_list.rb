module Google

  #
  # CalendarList is the main object you use to find Calendars.
  #
  class CalendarList

    attr_reader :connection

    #
    # Setup and connect to the user's list of Google Calendars.
    #
    # The +params+ parameter accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/). REQUIRED
    # * :client_secret => the client secret you received from Google after registering your application with them. REQUIRED
    # * :redirect_url => the url where your users will be redirected to after they have successfully permitted access to their calendars. Use 'urn:ietf:wg:oauth:2.0:oob' if you are using an 'application'" REQUIRED
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again). OPTIONAL
    #
    # See Readme.rdoc or readme_code.rb for an explication on the OAuth2 authorization process.
    #
    def initialize(params={}, connection=nil)
      @connection = connection || Connection.new(
        :client_id => params[:client_id],
        :client_secret => params[:client_secret],
        :refresh_token => params[:refresh_token],
        :redirect_url => params[:redirect_url]
      )
    end

    #
    # Find all entries on the user's calendar list. Returns an array of CalendarListEntry objects.
    #
    def fetch_entries
      response = @connection.send("/users/me/calendarList", :get)

      return nil if response.status != 200 || response.body.empty?

      CalendarListEntry.build_from_google_feed(JSON.parse(response.body))
    end

  end

end
