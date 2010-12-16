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
    #
    # After creating an instace you are immediatly logged on and ready to go.
    #
    # ==== Examples
    #   # Use the default calendar
    #   Calendar.new(username: => 'some.guy@gmail.com', :password => 'ilovepie!')
    #
    #   # Specify the calendar
    #   Calendar.new(username: => 'some.guy@gmail.com', :password => 'ilovepie!', :calendar => 'my.company@gmail.com')
    #
    def initialize(params)
      username = params[:username]
      password = params[:password]
      @calendar = params[:calendar]

      @connection = Connection.new(:username => username, :password => password)
    end

    # Find all of the events associated with this calendar.
    #  Returns:
    #   nil if nothing found.
    #   a single event if only one found.
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
    #   nil if nothing found.
    #   a single event if only one found.
    #   an array of events if many found.
    #
    def find_events(query)
      event_lookup("?q=#{query}")
    end

    # Attempts to find the event specified by the id
    #  Returns:
    #   nil if nothing found.
    #   a single event if only one found.
    #   an array of events if many found.
    #
    def find_event_by_id(id)
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
      setup_event(find_event_by_id(id) || Event.new, &blk)
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

    protected

    def event_lookup(query_string = '') #:nodoc:
      response = @connection.send(Addressable::URI.parse(events_url + query_string), :get)

      return nil if response.kind_of? Net::HTTPNotFound

      events = Event.build_from_google_feed(response.body, self)
      events.length > 1 ? events : events[0]
    end

    def calendar_url #:nodoc:
      @calendar || 'default'
    end

    def events_url #:nodoc:
      "https://www.google.com/calendar/feeds/#{calendar_url}/private/full"
    end

    def setup_event(event) #:nodoc:
      event.calendar = self
       yield(event) if block_given?
      event.save
      event
    end

  end

end