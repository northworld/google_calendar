module Google

  #
  # Represents a Google Calendar List Entry
  #
  # See https://developers.google.com/google-apps/calendar/v3/reference/calendarList#resource
  #
  # === Attributes
  #
  # * +id+ - The Google assigned id of the calendar. Read only.
  # * +summary+ - Title of the calendar. Read-only.
  # * +time_zone+ - The time zone of the calendar. Optional. Read-only.
  # * +access_role+ - The effective access role that the authenticated user has on the calendar. Read-only.
  # * +primary?+ - Whether the calendar is the primary calendar of the authenticated user. Read-only.
  #
  class CalendarListEntry
    attr_reader :id, :summary, :time_zone, :access_role, :primary, :connection
    alias_method :primary?, :primary

    def initialize(params, connection)
      @id = params['id']
      @summary = params['summary']
      @time_zone = params['timeZone']
      @access_role = params['accessRole']
      @primary = params.fetch('primary', false)
      @connection = connection
    end

    def to_calendar
      Calendar.new({:calendar => @id}, @connection)
    end

    def self.build_from_google_feed(response, connection)
      items = response['items']
      items.collect { |item| CalendarListEntry.new(item, connection) }
    end

  end

end
