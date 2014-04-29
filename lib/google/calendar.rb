require 'nokogiri'

module Google

  # Calendar is the main object you use to interact with events.
  # use it to find, create, update and delete them.
  #
  class Calendar

    # Setup and connect to the specified google calendar.
    #  the +params+ paramater accepts
    # * :username => the username of the specified calendar (i.e. some.guy@gmail.com)
    # * :password => the password for the specified user (i.e. super-secret)
    # * :calendar => the name of the calendar you would like to work with (optional, defaults to the calendar the user setup as their default one.)
    # * :app_name => the name of your application (defaults to 'northworld.com-googlecalendar-integration')
    # * :auth_url => the base url that is used to connect to google (defaults to 'https://www.google.com/accounts/ClientLogin')
    #
    # After creating an instace you are immediatly logged on and ready to go.
    #
    # ==== Examples
    #   # Use the default calendar
    #   Calendar.new(:username => 'some.guy@gmail.com', :password => 'ilovepie!')
    #
    #   # Specify the calendar
    #   Calendar.new(:username => 'some.guy@gmail.com', :password => 'ilovepie!', :calendar => 'my.company@gmail.com')
    #
    #   # Specify the app_name
    #   Calendar.new(:username => 'some.guy@gmail.com', :password => 'ilovepie!', :app_name => 'mycompany.com-googlecalendar-integration')
    #

    # Calendar attributes
    attr_accessor :username, :password, :app_name, :auth_url, :connection, :calendar

    def initialize(params)
      self.username = params[:username]
      self.password = params[:password]
      self.calendar = params[:calendar]
      self.app_name = params[:app_name]
      self.auth_url = params[:auth_url]

      self.connection = Connection.new(:username => username,
                                   :password => password,
                                   :app_name => app_name,
                                   :auth_url => auth_url)
    end

    # Find all of the events associated with this calendar.
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def events
      event_lookup()
    end

    # This is equivalnt to running a search in
    # the google calendar web application.  Google does not provide a way to easily specify
    # what attributes you would like to search (i.e. title), by default it searches everything.
    # If you would like to find specific attribute value (i.e. title=Picnic), run a query
    # and parse the results.
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_events(query)
      event_lookup("?q=#{query}")
    end

    # Find all of the events associated with this calendar that start in the given time frame.
    # The lower bound is inclusive, whereas the upper bound is exclusive.
    # Events that overlap the range are included.
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_events_in_range(start_min, start_max,options = {})
      options[:max_results] ||=  25
      options[:order_by] ||= 'lastmodified' # other option is 'starttime'
      formatted_start_min = start_min.strftime("%Y-%m-%dT%H:%M:%S")
      formatted_start_max = start_max.strftime("%Y-%m-%dT%H:%M:%S")
      query = "?start-min=#{formatted_start_min}&start-max=#{formatted_start_max}&recurrence-expansion-start=#{formatted_start_min}&recurrence-expansion-end=#{formatted_start_max}"
      query = "#{query}&orderby=#{options[:order_by]}&max-results=#{options[:max_results]}"
      event_lookup(query)
    end

    def find_future_events(options={})
      options[:max_results] ||=  25
      options[:order_by] ||= 'lastmodified' # other option is 'starttime'
      query = "?futureevents=true&orderby=#{options[:order_by]}&max-results=#{options[:max_results]}"
      event_lookup(query)
    end

    # Attempts to find the event specified by the id
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_event_by_id(id)
      return nil unless id && id.strip != ''
      event_lookup("/#{id}")
    end

    # Creates a new event and immediatly saves it.
    # returns the event
    #
    # ==== Examples
    #   # Use a block
    #   cal.create_event do |e|
    #     e.title = "A New Event"
    #     e.where = "Room 101"
    #   end
    #
    #   # Don't use a block (need to call save maunally)
    #   event  = cal.create_event
    #   event.title = "A New Event"
    #   event.where = "Room 101"
    #   event.save
    #
    def create_event(&blk)
      setup_event(Event.new, &blk)
    end

    # looks for the spedified event id.
    # If it is found it, updates it's vales and returns it.
    # If the event is no longer on the server it creates a new one with the specified values.
    # Works like the create_event method.
    #
    def find_or_create_event_by_id(id, &blk)
      setup_event(find_event_by_id(id)[0] || Event.new, &blk)
    end

    # Saves the specified event.
    # This is a callback used by the Event class.
    #
    def save_event(event)
      method = (event.id == nil || event.id == '') ? :post : :put
      query_string = (method == :put) ? "/#{event.id}" : ''
      @connection.send(Addressable::URI.parse(events_url + query_string), method, event.to_xml)
    end

    # Deletes the specified event.
    # This is a callback used by the Event class.
    #
    def delete_event(event)
      @connection.send(Addressable::URI.parse(events_url + "/#{event.id}"), :delete)
    end

    # Explicitly reload the connection to google calendar
    #
    # Examples
    # class User
    #   def calendar
    #     @calendar ||= Google::Calendar.new :username => "foo@gmail.com", :password => "bar"
    #   end
    # end
    # user = User.new
    # 2.times { user.calendar }     #only one HTTP authentication request to google
    # user.calendar.reload          #new HTTP authentication request to google
    #
    # Returns Google::Calendar instance
    def reload
      self.connection = Connection.new(:username => username,
                                   :password => password,
                                   :app_name => app_name,
                                   :auth_url => auth_url)
      self
    end
    
    def display_color
      calendar_data.xpath("//entry[title='#{@calendar}']/color/@value").first.value
    end

    protected

    def event_lookup(query_string = '') #:nodoc:
      begin
      response = @connection.send(Addressable::URI.parse(events_url + query_string), :get)
      events = Event.build_from_google_feed(response.body, self) || []
      return events if events.empty?
      events.length > 1 ? events : [events[0]]
      rescue Google::HTTPNotFound
        return nil
      end
    end

    def calendar_id #:nodoc:
      @calendar || "default"
    end

    # Initialize the events URL given String attribute @calendar value :
    #
    # contains a '@'        : construct the feed url with @calendar.
    # does not contain '@'  : fetch user's all calendars (http://code.google.com/apis/calendar/data/2.0/developers_guide_protocol.html#RetrievingAllCalendars)
    #                         and return feed url matching @calendar.
    # nil                   : default feed url.
    #
    # Returns:
    #  a String url for a calendar feeds.
    #  raise a Google::InvalidCalendar error if @calendar is invalid.
    #
    def events_url
      if @calendar and !@calendar.include?("@")
         link = calendar_data.xpath("//entry[title='#{@calendar}']/link[contains(@rel, '#eventFeed')]/@href").to_s
         link.empty? ? raise(Google::InvalidCalendar) : link
       else
         "https://www.google.com/calendar/feeds/#{calendar_id}/private/full"
      end
    end
    
    def calendar_data
      unless @calendar_data
        xml = @connection.send(Addressable::URI.parse("https://www.google.com/calendar/feeds/default/allcalendars/full"), :get)
        @calendar_data = Nokogiri::XML(xml.body)
        @calendar_data.remove_namespaces!
      end
      @calendar_data
    end

    def setup_event(event) #:nodoc:
      event.calendar = self
      if block_given?
      	yield(event)
      	event.title = event.title.encode(:xml => :text) if event.title
      	event.content = event.content.encode(:xml => :text) if event.content
      	event.where = event.where.encode(:xml => :text) if event.where
      end
      event.save
      event
    end
  end

end
