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
  #
  class Event
    attr_reader :raw, :html_link, :status
    attr_accessor :id, :title, :location, :calendar, :quickadd, :transparency, :attendees, :description, :reminders, :recurrence, :visibility, :creator_name, :color_id, :extended_properties, :guests_can_invite_others, :guests_can_see_other_guests

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
    #
    def initialize(params = {})
      [:id, :status, :raw, :html_link, :title, :location, :calendar, :quickadd, :attendees, :description, :reminders, :recurrence, :start_time, :end_time, :color_id, :extended_properties, :guests_can_invite_others, :guests_can_see_other_guests].each do |attribute|
        instance_variable_set("@#{attribute}", params[attribute])
      end

      self.visibility   = params[:visibility]
      self.transparency = params[:transparency]
      self.all_day      = params[:all_day] if params[:all_day]
      self.creator_name = params[:creator]['displayName'] if params[:creator]
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
      raise ArgumentError, "End Time must be either Time or String" unless (time.is_a?(String) || time.is_a?(Time))
      @end_time = (time.is_a? String) ? Time.parse(time) : time.dup.utc
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
      "{
        \"summary\": \"#{title}\",
        \"visibility\": \"#{visibility}\",
        \"description\": \"#{description}\",
        \"location\": \"#{location}\",
        \"start\": {
          \"dateTime\": \"#{start_time}\"
          #{timezone_needed? ? local_timezone_json : ''}
        },
        \"end\": {
          \"dateTime\": \"#{end_time}\"
          #{timezone_needed? ? local_timezone_json : ''}
        },
        #{recurrence_json}
        #{color_json}
        #{attendees_json}
        #{extended_properties_json}
        \"reminders\": {
          #{reminders_json}
        },
        \"guestsCanInviteOthers\": #{guests_can_invite_others.to_json},
        \"guestsCanSeeOtherGuests\": #{guests_can_see_other_guests.to_json}
      }"
    end

    def color_json
      return unless color_id
      "\"colorId\": \"#{color_id}\","
    end
    #
    # JSON representation of attendees
    #
    def attendees_json
      return unless @attendees

      attendees = @attendees.map do |attendee|
        "{
          \"displayName\": \"#{attendee['displayName']}\",
          \"email\": \"#{attendee['email']}\",
          \"responseStatus\": \"#{attendee['responseStatus']}\"
        }"
      end.join(",\n")

      "\"attendees\": [\n#{attendees}],"
    end

    #
    # JSON representation of a reminder
    #
    def reminders_json
      if reminders && reminders.is_a?(Hash) && reminders['overrides']
        overrides = reminders['overrides'].map do |reminder|
          "{
            \"method\": \"#{reminder['method']}\",
            \"minutes\": #{reminder['minutes']}
          }"
        end.join(",\n")
        "\n\"useDefault\": false,\n\"overrides\": [\n#{overrides}]"
      else
        "\"useDefault\": true"
      end
    end

    #
    # Timezone info is needed only at recurring events
    #
    def timezone_needed?
      @recurrence && @recurrence[:freq]
    end

    #
    # JSON representation of local timezone
    #
    def local_timezone_json
      tz = Time.now.getlocal.zone
      tz_name = TimezoneParser::getTimezones(tz).last
      ",\"timeZone\" : \"#{tz_name}\""
    end

    #
    # JSON representation of recurrence rules for repeating events
    #
    def recurrence_json
      return unless @recurrence && @recurrence[:freq]

      @recurrence[:until] = @recurrence[:until].strftime('%Y%m%dT%H%M%SZ') if @recurrence[:until]
      rrule = "RRULE:" + @recurrence.collect { |k,v| "#{k}=#{v}" }.join(';').upcase
      @recurrence[:until] = Time.parse(@recurrence[:until]) if @recurrence[:until]

      "\"recurrence\": [\n\"#{rrule}\"],"
    end

    #
    # JSON representation of extended properties
    # shared : whether this should handle shared or public properties
    #
    def extended_properties_json
      return unless @extended_properties && (@extended_properties['shared'] || @extended_properties['private'])
      json_extended_properties = []
      ['shared', 'private'].each do |prop_type|
        if @extended_properties[prop_type]
          props_json = @extended_properties[prop_type].map do |key, value|
            "\"#{key}\": \"#{value}\""
          end.join(",\n")
          json_extended_properties << "\"#{prop_type}\": {\n
                                          #{props_json}
                                      }\n"
        end
      end
      "\n\"extendedProperties\": {\n
        #{json_extended_properties.join(',')}\n
      },\n"
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
      id == nil || id == ''
    end

    protected

    #
    # Create a new event from a google 'entry'
    #
    def self.new_from_feed(e, calendar) #:nodoc:
      Event.new(:id           => e['id'],
                :calendar     => calendar,
                :status       => e['status'],
                :raw          => e,
                :title        => e['summary'],
                :description  => e['description'],
                :location     => e['location'],
                :creator      => e['creator'],
                :start_time   => Event.parse_json_time(e['start']),
                :end_time     => Event.parse_json_time(e['end']),
                :transparency => e['transparency'],
                :html_link    => e['htmlLink'],
                :updated      => e['updated'],
                :reminders    => e['reminders'],
                :attendees    => e['attendees'],
                :recurrence   => Event.parse_recurrence_rule(e['recurrence']),
                :visibility   => e['visibility'],
                :color_id     => e['colorId'],
                :extended_properties => e['extendedProperties'],
                :guests_can_invite_others => e['guestsCanInviteOthers'],
                :guests_can_see_other_guests => e['guestsCanSeeOtherGuests'])

    end

    #
    # Parse recurrence rule
    # Returns hash with recurrence info
    #
    def self.parse_recurrence_rule(recurrence_entry)
      return {} unless recurrence_entry && recurrence_entry != []

      rrule = recurrence_entry[0].sub('RRULE:', '')
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

    def self.parse_json_time(time_hash)
      return nil unless time_hash

      if time_hash['date']
        Time.parse(time_hash['date']).utc
      elsif time_hash['dateTime']
        Time.parse(time_hash['dateTime']).utc
      else
        Time.now.utc
      end
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
      raise ArgumentError, "Event ID is invalid. Please check Google documentation: https://developers.google.com/google-apps/calendar/v3/reference/events/insert" unless id.gsub(/(^[a-v0-9]{5,1024}$)/o)
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
