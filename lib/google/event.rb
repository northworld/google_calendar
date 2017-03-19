require 'time'
require 'json'
require 'timezone_parser'

module Google

  #
  # Represents a Google Event.
  #
  # === Attributes
  #
  # * +id+ - The google assigned id of the event (nil until saved). Read Write.
  # * +status+ - The status of the event (confirmed, tentative or cancelled). Read only.
  # * +title+ - The title of the event. Read Write.
  # * +description+ - The content of the event. Read Write.
  # * +location+ - The location of the event. Read Write.
  # * +start_time+ - The start time of the event (Time object, defaults to now). Read Write.
  # * +end_time+ - The end time of the event (Time object, defaults to one hour from now).  Read Write.
  # * +recurrence+ - A hash containing recurrence info for repeating events. Read write.
  # * +calendar+ - What calendar the event belongs to. Read Write.
  # * +all_day+ - Does the event run all day. Read Write.
  # * +quickadd+ - A string that Google parses when setting up a new event.  If set and then saved it will take priority over any attributes you have set. Read Write.
  # * +reminders+ - A hash containing reminders. Read Write.
  # * +attendees+ - An array of hashes containing information about attendees. Read Write
  # * +transparency+ - Does the event 'block out space' on the calendar.  Valid values are true, false or 'transparent', 'opaque'. Read Write.
  # * +duration+ - The duration of the event in seconds. Read only.
  # * +html_link+ - An absolute link to this event in the Google Calendar Web UI. Read only.
  # * +raw+ - The full google json representation of the event. Read only.
  # * +visibility+ - The visibility of the event (*'default'*, 'public', 'private', 'confidential'). Read Write.
  # * +extended_properties+ - Custom properties which may be shared or private. Read Write
  # * +guests_can_invite_others+ - Whether attendees other than the organizer can invite others to the event (*true*, false). Read Write.
  # * +guests_can_see_other_guests+ - Whether attendees other than the organizer can see who the event's attendees are (*true*, false). Read Write.
  # * +send_notifications+ - Whether to send notifications about the event update (true, *false*). Write only.
  #
  class Event
    attr_reader :id, :raw, :html_link, :status, :transparency, :visibility
    attr_writer :reminders, :recurrence, :extended_properties
    attr_accessor :title, :location, :calendar, :quickadd, :attendees, :description, :creator_name, :color_id, :guests_can_invite_others, :guests_can_see_other_guests, :send_notifications, :new_event_with_id_specified

    #
    # Create a new event, and optionally set it's attributes.
    #
    # ==== Example
    #
    # event = Google::Event.new
    # event.calendar = AnInstanceOfGoogleCalendaer
    # event.id = "0123456789abcdefghijklmopqrstuv"
    # event.start_time = Time.now
    # event.end_time = Time.now + (60 * 60)
    # event.recurrence = {'freq' => 'monthly'}
    # event.title = "Go Swimming"
    # event.description = "The polar bear plunge"
    # event.location = "In the arctic ocean"
    # event.transparency = "opaque"
    # event.visibility = "public"
    # event.reminders = {'useDefault'  => false, 'overrides' => ['minutes' => 10, 'method' => "popup"]}
    # event.attendees = [
    #                     {'email' => 'some.a.one@gmail.com', 'displayName' => 'Some A One', 'responseStatus' => 'tentative'},
    #                     {'email' => 'some.b.one@gmail.com', 'displayName' => 'Some B One', 'responseStatus' => 'tentative'}
    #                   ]
    # event.extendedProperties = {'shared' => {'custom_str' => 'some custom string'}}
    # event.guests_can_invite_others = false
    # event.guests_can_see_other_guests = false
    # event.send_notifications = true
    #
    def initialize(params = {})
      [:id, :status, :raw, :html_link, :title, :location, :calendar, :quickadd, :attendees, :description, :reminders, :recurrence, :start_time, :end_time, :color_id, :extended_properties, :guests_can_invite_others, :guests_can_see_other_guests, :send_notifications].each do |attribute|
        instance_variable_set("@#{attribute}", params[attribute])
      end

      self.visibility   = params[:visibility]
      self.transparency = params[:transparency]
      self.all_day      = params[:all_day] if params[:all_day]
      self.creator_name = params[:creator]['displayName'] if params[:creator]
      self.new_event_with_id_specified = !!params[:new_event_with_id_specified]
    end

    #
    # Sets the id of the Event.
    #
    def id=(id)
      @id = Event.parse_id(id) unless id.nil?
    end

    #
    # Sets the start time of the Event.  Must be a Time object or a parse-able string representation of a time.
    #
    def start_time=(time)
      @start_time = Event.parse_time(time)
    end

    #
    # Get the start_time of the event.
    #
    # If no time is set (i.e. new event) it defaults to the current time.
    #
    def start_time
      @start_time ||= Time.now.utc
      (@start_time.is_a? String) ? @start_time : @start_time.xmlschema
    end

    #
    # Get the end_time of the event.
    #
    # If no time is set (i.e. new event) it defaults to one hour in the future.
    #
    def end_time
      @end_time ||= Time.now.utc + (60 * 60) # seconds * min
      (@end_time.is_a? String) ? @end_time : @end_time.xmlschema
    end

    #
    # Sets the end time of the Event.  Must be a Time object or a parse-able string representation of a time.
    #
    def end_time=(time)
      @end_time = Event.parse_time(time)
    end

    #
    # Returns whether the Event is an all-day event, based on whether the event starts at the beginning and ends at the end of the day.
    #
    def all_day?
      time = (@start_time.is_a?  String) ? Time.parse(@start_time) : @start_time.dup.utc
      duration % (24 * 60 * 60) == 0 && time == Time.local(time.year,time.month,time.day)
    end

    #
    # Makes an event all day, by setting it's start time to the passed in time and it's end time 24 hours later.
    # Note: this will clobber both the start and end times currently set.
    #
    def all_day=(time)
      if time.class == String
        time = Time.parse(time)
      end
      @start_time = time.strftime("%Y-%m-%d")
      @end_time = (time + 24*60*60).strftime("%Y-%m-%d")
    end

    #
    # Duration of the event in seconds
    #
    def duration
      Time.parse(end_time) - Time.parse(start_time)
    end

    #
    # Stores reminders for this event. Multiple reminders are allowed.
    #
    # Examples
    #
    # event = cal.create_event do |e|
    #   e.title = 'Some Event'
    #   e.start_time = Time.now + (60 * 10)
    #   e.end_time = Time.now + (60 * 60) # seconds * min
    #   e.reminders = { 'useDefault'  => false, 'overrides' => [{method: 'email', minutes: 4}, {method: 'popup', minutes: 60}, {method: 'sms', minutes: 30}]}
    # end
    #
    # event = Event.new :start_time => "2012-03-31", :end_time => "2012-04-03", :reminders => { 'useDefault'  => false, 'overrides' => [{'minutes' => 10, 'method' => "popup"}]}
    #
    def reminders
      @reminders ||= {}
    end

    #
    # Stores recurrence rules for repeating events.
    #
    # Allowed contents:
    # :freq => frequence information ("daily", "weekly", "monthly", "yearly")   REQUIRED
    # :count => how many times the repeating event should occur                 OPTIONAL
    # :until => Time class, until when the event should occur                   OPTIONAL
    # :interval => how often should the event occur (every "2" weeks, ...)      OPTIONAL
    # :byday => if frequence is "weekly", contains ordered (starting with       OPTIONAL
    #             Sunday)comma separated abbreviations of days the event
    #             should occur on ("su,mo,th")
    #           if frequence is "monthly", can specify which day of month
    #             the event should occur on ("2mo" - second Monday, "-1th" - last Thursday,
    #             allowed indices are 1,2,3,4,-1)
    #
    # Note: The hash should not contain :count and :until keys simultaneously.
    #
    # ===== Example
    # event = cal.create_event do |e|
    #   e.title = 'Work-day Event'
    #   e.start_time = Time.now
    #   e.end_time = Time.now + (60 * 60) # seconds * min
    #   e.recurrence = {freq: "weekly", byday: "mo,tu,we,th,fr"}
    # end
    #
    def recurrence
      @recurrence ||= {}
    end

    #
    # Stores custom data within extended properties which can be shared or private.
    #
    # Allowed contents:
    # :private => a hash containing custom key/values (strings) private to the event   OPTIONAL
    # :shared => a hash containing custom key/values (strings) shared with others       OPTIONAL
    #
    # Note: Both private and shared can be specified at once
    #
    # ===== Example
    # event = cal.create_event do |e|
    #   e.title = 'Work-day Event'
    #   e.start_time = Time.now
    #   e.end_time = Time.now + (60 * 60) # seconds * min
    #   e.extended_properties = {'shared' => {'prop1' => 'value 1'}}
    # end
    #
    def extended_properties
      @extended_properties ||= {}
    end

    #
    # Utility method that simplifies setting the transparency of an event.
    # You can pass true or false.  Defaults to transparent.
    #
    def transparency=(val)
      if val == false || val.to_s.downcase == 'opaque'
        @transparency = 'opaque'
      else
        @transparency = 'transparent'
      end
    end

    #
    # Returns true if the event is transparent otherwise returns false.
    # Transparent events do not block time on a calendar.
    #
    def transparent?
      @transparency == "transparent"
    end

    #
    # Returns true if the event is opaque otherwise returns false.
    # Opaque events block time on a calendar.
    #
    def opaque?
      @transparency == "opaque"
    end

    #
    # Sets the visibility of the Event.
    #
    def visibility=(val)
      if val
        @visibility = Event.parse_visibility(val)
      else
        @visibility = "default"
      end
    end

    #
    # Convenience method used to build an array of events from a Google feed.
    #
    def self.build_from_google_feed(response, calendar)
      events = response['items'] ? response['items'] : [response]
      events.collect {|e| new_from_feed(e, calendar)}.flatten
    end

    #
    # Google JSON representation of an event object.
    #
    def to_json
      attributes = {
        "summary" => title,
        "visibility" => visibility,
        "transparency" => transparency,
        "description" => description,
        "location" => location,
        "start" => time_or_all_day(start_time),
        "end" => time_or_all_day(end_time),
        "reminders" => reminders_attributes,
        "guestsCanInviteOthers" => guests_can_invite_others,
        "guestsCanSeeOtherGuests" => guests_can_see_other_guests
      }

      attributes["id"] = id if id
      attributes['start'].merge!(local_timezone_attributes)
      attributes['end'].merge!(local_timezone_attributes)

      attributes.merge!(recurrence_attributes)
      attributes.merge!(color_attributes)
      attributes.merge!(attendees_attributes)
      attributes.merge!(extended_properties_attributes)

      JSON.generate attributes
    end

    #
    # Hash representation of colors
    #
    def color_attributes
      return {} unless color_id
      { "colorId" => "#{color_id}" }
    end

    #
    # JSON representation of colors
    #
    def color_json
      color_attributes.to_json
    end

    #
    # Hash representation of attendees
    #
    def attendees_attributes
      return {} unless @attendees

      attendees = @attendees.map do |attendee|
        attendee.select { |k,v| ['displayName', 'email', 'responseStatus'].include?(k) }
      end

      { "attendees" => attendees }
    end

    #
    # JSON representation of attendees
    #
    def attendees_json
      attendees_attributes.to_json
    end

    #
    # Hash representation of a reminder
    #
    def reminders_attributes
      if reminders && reminders.is_a?(Hash) && reminders['overrides']

        { "useDefault" => false, "overrides" => reminders['overrides'] }
      else
        { "useDefault" => true}
      end
    end

    #
    # JSON representation of a reminder
    #
    def reminders_json
      reminders_attributes.to_json
    end

    #
    # Timezone info is needed only at recurring events
    #
    def timezone_needed?
      is_recurring_event?
    end

    #
    # Hash representation of local timezone
    #
    def local_timezone_attributes
      tz = Time.now.getlocal.zone
      tz_name = TimezoneParser::getTimezones(tz).last
      { "timeZone" => tz_name }
    end

    #
    # JSON representation of local timezone
    #
    def local_timezone_json
      local_timezone_attributes.to_json
    end

    #
    # Hash representation of recurrence rules for repeating events
    #
    def recurrence_attributes
      return {} unless is_recurring_event?

      @recurrence[:until] = @recurrence[:until].strftime('%Y%m%dT%H%M%SZ') if @recurrence[:until]
      rrule = "RRULE:" + @recurrence.collect { |k,v| "#{k}=#{v}" }.join(';').upcase
      @recurrence[:until] = Time.parse(@recurrence[:until]) if @recurrence[:until]

      { "recurrence" => [rrule] }
    end

    #
    # JSON representation of recurrence rules for repeating events
    #
    def recurrence_json
      recurrence_attributes.to_json
    end

    #
    # Hash representation of extended properties
    # shared : whether this should handle shared or public properties
    #
    def extended_properties_attributes
      return {} unless @extended_properties && (@extended_properties['shared'] || @extended_properties['private'])

      { "extendedProperties" => @extended_properties.select {|k,v| ['shared', 'private'].include?(k) } }
    end

    #
    # JSON representation of extended properties
    # shared : whether this should handle shared or public properties
    #
    def extended_properties_json
      extended_properties_attributes.to_json
    end

    #
    # String representation of an event object.
    #
    def to_s
      "Event Id '#{self.id}'\n\tStatus: #{status}\n\tTitle: #{title}\n\tStarts: #{start_time}\n\tEnds: #{end_time}\n\tLocation: #{location}\n\tDescription: #{description}\n\tColor: #{color_id}\n\n"
    end

    #
    # Saves an event.
    #  Note: make sure to set the calendar before calling this method.
    #
    def save
      update_after_save(@calendar.save_event(self))
    end

    #
    # Deletes an event.
    #  Note: If using this on an event you created without using a calendar object,
    #  make sure to set the calendar before calling this method.
    #
    def delete
      @calendar.delete_event(self)
      @id = nil
    end

    #
    # Returns true if the event will use quickadd when it is saved.
    #
    def use_quickadd?
      quickadd && id == nil
    end

    #
    # Returns true if this a new event.
    #
    def new_event?
      new_event_with_id_specified? || id == nil || id == ''
    end

    #
    # Returns true if notifications were requested to be sent
    #
    def send_notifications?
      !!send_notifications
    end


    private

    def new_event_with_id_specified?
      !!new_event_with_id_specified
    end

    def time_or_all_day(time)
      time = Time.parse(time) if time.is_a? String

      if all_day?
        { "date" => time.strftime("%Y-%m-%d") }
      else
        { "dateTime" => time.xmlschema }
      end
    end

    protected

    #
    # Create a new event from a google 'entry'
    #
    def self.new_from_feed(e, calendar) #:nodoc:
      params = {}
      %w(id status description location creator transparency updated reminders attendees visibility).each do |p|
        params[p.to_sym] = e[p]
      end

      params[:raw] = e
      params[:calendar] = calendar
      params[:title] = e['summary']
      params[:color_id] = e['colorId']
      params[:extended_properties] = e['extendedProperties']
      params[:guests_can_invite_others] = e['guestsCanInviteOthers']
      params[:guests_can_see_other_guests] = e['guestsCanSeeOtherGuests']
      params[:html_link] = e['htmlLink']
      params[:start_time] = Event.parse_json_time(e['start'])
      params[:end_time] = Event.parse_json_time(e['end'])
      params[:recurrence] = Event.parse_recurrence_rule(e['recurrence'])

      Event.new(params)
    end

    #
    # Parse recurrence rule
    # Returns hash with recurrence info
    #
    def self.parse_recurrence_rule(recurrence_entry)
      return {} unless recurrence_entry && recurrence_entry != []

      rrule = /(?<=RRULE:)(.*)(?="\])/.match(recurrence_entry.to_s).to_s
      rhash = Hash[*rrule.downcase.split(/[=;]/)]

      rhash[:until] = Time.parse(rhash[:until]) if rhash[:until]
      rhash
    end

    #
    # Set the ID after google assigns it (only necessary when we are creating a new event)
    #
    def update_after_save(response) #:nodoc:
      return if @id && @id != ''
      @raw = JSON.parse(response.body)
      @id = @raw['id']
      @html_link = @raw['htmlLink']
    end

    #
    # A utility method used to centralize parsing of time in json format
    #
    def self.parse_json_time(time_hash) #:nodoc
      return nil unless time_hash

      if time_hash['date']
        Time.parse(time_hash['date'])
      elsif time_hash['dateTime']
        Time.parse(time_hash['dateTime'])
      else
        Time.now
      end
    end

    #
    # A utility method used to centralize checking for recurring events
    #
    def is_recurring_event? #:nodoc
      @recurrence && (@recurrence[:freq] || @recurrence['FREQ'] || @recurrence['freq'])
    end

    #
    # A utility method used centralize time parsing.
    #
    def self.parse_time(time) #:nodoc
      raise ArgumentError, "Start Time must be either Time or String" unless (time.is_a?(String) || time.is_a?(Time))
      (time.is_a? String) ? Time.parse(time) : time.dup.utc
    end

    #
    # Validates id format
    #
    def self.parse_id(id)
      if id.to_s =~ /\A[a-v0-9]{5,1024}\Z/
        id
      else
        raise ArgumentError, "Event ID is invalid. Please check Google documentation: https://developers.google.com/google-apps/calendar/v3/reference/events/insert"
      end
    end

    #
    # Validates visibility value
    #
    def self.parse_visibility(visibility)
      raise ArgumentError, "Event visibility must be 'default', 'public', 'private' or 'confidential'." unless ['default', 'public', 'private', 'confidential'].include?(visibility)
      return visibility
    end

  end
end
