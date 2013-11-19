module Google
  class AuthenticatedConnection < Connection
    def initialize params
      calendar_name = params[:calendar_name]
      calendar_id = params[:calendar_id]

      @username = params[:username]
      @password = params[:password]
      @auth_url = params[:auth_url] || "https://www.google.com/accounts/ClientLogin"
      @app_name = params[:app_name] || "northworld.com-googlecalendar-integration"

      login

      if calendar_name
        @events_url = look_up_events_url_by_calendar_name calendar_name
      elsif calendar_id
        @events_url = "#{BASE_URI}/#{CGI::escape calendar_id}/private/full"
      else
        @events_url = "#{BASE_URI}/default/private/full"
      end
    end

    def reload
      @session_id = nil
      login
    end

    private

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
