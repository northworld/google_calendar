require 'time'
require 'json'

module Google

  #
  # Freebusy returns free/busy information for a set of calendars
  #
  class Freebusy

    attr_reader :connection

    #
    # Setup and query the free/busy status of a collection of calendars.
    #
    # The +params+ parameter accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/). REQUIRED
    # * :client_secret => the client secret you received from Google after registering your application with them. REQUIRED
    # * :redirect_url => the url where your users will be redirected to after they have successfully permitted access to their calendars. REQUIRED
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again). OPTIONAL
    #
    # See Readme.rdoc or readme_code.rb for an explication on the OAuth2 authorization process.
    #
    def initialize(params={}, connection=nil)
      @connection = connection || Connection.factory(params)
    end

    #
    # Find the busy times of the supplied calendar IDs, within the boundaries
    # of the supplied start_time and end_time
    #
    # The arguments supplied are
    # * calendar_ids => array of Google calendar IDs as strings
    # * start_time => a Time object, the start of the interval for the query.
    # * end_time => a Time object, the end of the interval for the query.
    #
    def query(calendar_ids, start_time, end_time)
      query_content = json_for_query(calendar_ids, start_time, end_time)
      response = @connection.send("/freeBusy", :post, query_content)

      return nil if response.status != 200 || response.body.empty?

      parse_freebusy_response(response.body)
    end

    private

    #
    # Prepare the JSON
    #
    def json_for_query(calendar_ids, start_time, end_time)
      {}.tap{ |obj|
        obj[:items] = calendar_ids.map {|id| Hash[:id, id] }
        obj[:timeMin] = start_time.utc.iso8601
        obj[:timeMax] = end_time.utc.iso8601
      }.to_json
    end

    def parse_freebusy_response(response_body)
      query_result = JSON.parse(response_body)

      return nil unless query_result['calendars'].is_a? Hash

      query_result['calendars'].each_with_object({}) do |(calendar_id, value), result|
        value['busy'].each { |date_times| date_times.transform_values! { |date_time| DateTime.parse(date_time) } }
        result[calendar_id] = value['busy'] || []
      end
    end
  end
end
