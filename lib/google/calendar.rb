require 'nokogiri'

module Google

  # Calendar is the main object you use to interact with events.
  # use it to find, create, update and delete them.
  #
  class Calendar

    attr_reader :connection

    # Setup and connect to the specified google calendar.
    #  the +params+ paramater accepts
    # * :username => the username of the specified calendar (i.e. some.guy@gmail.com. Leave this out if you'd like to access a public calendar)
    # * :password => the password for the specified user (i.e. super-secret. Leave this out if you'd like to access a public calendar)
    # * :calendar => the name or ID of the calendar you would like to work with (Defaults to the calendar the user setup as their default one if credentials are provided. Set this value with the calendar's ID when accessing a public calendar)
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
    #   # Specify a public calendar
    #   Calendar.new(:calendar => 'en.singapore#holiday@group.v.calendar.google.com')
    #
    def initialize(params)
      options = {
        :username => params[:username],
        :password => params[:password],
        :app_name => params[:app_name],
        :auth_url => params[:auth_url]
      }

      calendar_name_or_id = params[:calendar]
      if calendar_name_or_id and !calendar_name_or_id.include?("@")
        @calendar_name = calendar_name_or_id
        options[:calendar_name] = @calendar_name
      else
        @calendar_id = calendar_name_or_id
        options[:calendar_id] = @calendar_id
      end

      @connection = Connection.connect options
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
      formatted_start_min = Addressable::URI.encode_component(start_min.strftime("%FT%T%:z"), Addressable::URI::CharacterClasses::UNRESERVED)
      formatted_start_max = Addressable::URI.encode_component(start_max.strftime("%FT%T%:z"), Addressable::URI::CharacterClasses::UNRESERVED)
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
      @connection.send_events_request(query_string, :method, event.to_xml)
    end

    # Deletes the specified event.
    # This is a callback used by the Event class.
    #
    def delete_event(event)
      @connection.send_events_request("/#{event.id}", :delete)
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
      @connection.reload
      self
    end

    def display_color
      @connection.list_calendars.xpath("//entry[title='#{@calendar_name}']/color/@value").first.value
    end

    protected

    def event_lookup(query_string = '') #:nodoc:
      begin
        response = @connection.send_events_request(query_string, :get)
        events = Event.build_from_google_feed(response.body, self) || []
        return events if events.empty?
        events.length > 1 ? events : [events[0]]
      rescue Google::HTTPNotFound
        return nil
      end
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
