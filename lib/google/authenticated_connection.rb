module Google
  # This is a utility class that performs communication with the google calendar api that requires authentication.
  #
  class AuthenticatedConnection < Connection
    # set the username, password, auth_url, app_name, login and prepare events_url.
    #
    def initialize params
      @username = params[:username]
      @password = params[:password]
      @auth_url = params[:auth_url] || "https://www.google.com/accounts/ClientLogin"
      @app_name = params[:app_name] || "northworld.com-googlecalendar-integration"

      login

      calendar_name = params[:calendar_name]
      calendar_id = params[:calendar_id]

      if calendar_name
        @events_url = look_up_events_url_by_calendar_name calendar_name
      elsif calendar_id
        @events_url = "#{BASE_URI}/#{CGI::escape calendar_id}/private/full"
      else
        @events_url = "#{BASE_URI}/default/private/full"
      end
    end

    # reset session_id and login again
    #
    def reload
      @session_id = nil
      login
    end

    private

    # login to the google calendar and grab an auth token.
    #
    def login
      content = {
        'Email' => @username,
        'Passwd' => @password,
        'source' => @app_name,
        'accountType' => 'HOSTED_OR_GOOGLE',
        'service' => 'cl'}

      response = send(Addressable::URI.parse(@auth_url), :post_form, content)

      raise HTTPRequestFailed unless response.kind_of? Net::HTTPSuccess

      @token = response.body.split('=').last
      @headers = {
         'Authorization' => "GoogleLogin auth=#{@token}",
         'Content-Type'  => 'application/atom+xml'
       }
       @update_header = @headers.clone
       @update_header["If-Match"] = "*"
    end

    def look_up_events_url_by_calendar_name calendar_name
      events_url = list_calendars.xpath("//entry[title='#{calendar_name}']/link[contains(@rel, '#eventFeed')]/@href").to_s
      events_url.empty? ? raise(Google::InvalidCalendar) : events_url
    end

    # fetch, memoize and return the list of sign-in user's calendars.
    #
    def list_calendars
      unless @calendars
        xml = send(Addressable::URI.parse("#{BASE_URI}/default/allcalendars/full"), :get)
        @calendars = Nokogiri::XML(xml.body)
        @calendars.remove_namespaces!
      end
      @calendars
    end
  end
end
