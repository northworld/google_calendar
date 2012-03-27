require 'nokogiri'
require 'time'

module Google

  # Represents a google Event.
  #
  # === Attributes
  #
  # * +id+ - The google assigned id of the event (nil until saved), read only.
  # * +title+ - The title of the event, read/write.
  # * +content+ - The content of the event, read/write.
  # * +start_time+ - The start time of the event (Time object, defaults to now), read/write.
  # * +end_time+ - The end time of the event (Time object, defaults to one hour from now), read/write.
  # * +calendar+ - What calendar the event belongs to, read/write.
  # * +raw_xml+ - The full google xml representation of the event.
  #
  class Event
    attr_reader :id, :raw_xml
    attr_accessor :title, :content, :where, :calendar, :quickadd

    # Create a new event, and optionally set it's attributes.
    #
    # ==== Example
    #  Event.new(:title => 'Swimming',
    #           :content => 'Do not forget a towel this time',
    #           :where => 'The Ocean',
    #           :start_time => Time.now,
    #           :end_time => Time.now + (60 * 60),
    #           :calendar => calendar_object)
    #
    def initialize(params = {})
      @id = params[:id]
      @title = params[:title]
      @content = params[:content]
      @where = params[:where]
      @start_time = params[:start_time]
      @end_time = params[:end_time]
      @calendar = params[:calendar]
      @raw_xml = params[:raw_xml]
      @quickadd = params[:quickadd]
    end

    # Sets the start time of the Event.  Must be a Time object or a parsable string representation of a time.
    #
    def start_time=(time)
      raise ArgumentError, "Start Time must be either Time or String" unless (time.is_a?(String) || time.is_a?(Time))
      @start_time = (time.is_a? String) ? Time.parse(time) : time
    end

    # Get the start_time of the event.
    #
    # If no time is set (i.e. new event) it defaults to the current time.
    #
    def start_time
      @start_time ||= Time.now
      (@start_time.is_a? String) ? @start_time : @start_time.utc.xmlschema
    end

    # Get the end_time of the event.
    #
    # If no time is set (i.e. new event) it defaults to one hour in the future.
    #
    def end_time
      @end_time ||= Time.now + (60 * 60) # seconds * min
      (@end_time.is_a? String) ? @end_time : @end_time.utc.xmlschema
    end

    # Sets the end time of the Event.  Must be a Time object or a parsable string representation of a time.
    #
    def end_time=(time)
      raise ArgumentError, "End Time must be either Time or String" unless (time.is_a?(String) || time.is_a?(Time))
      @end_time = ((time.is_a? String) ? Time.parse(time) : time)
    end
    
    # Returns whether the Event is an all-day event, based on whether the event starts at the beginning and ends at the end of the day.
    #
    def all_day?
      duration == 24 * 60 * 60 # Exactly one day
    end
    
    # Duration in seconds
    def duration
      Time.parse(end_time) - Time.parse(start_time)
    end

    #
    def self.build_from_google_feed(xml, calendar)
      Nokogiri::XML(xml).xpath("//xmlns:entry").collect {|e| new_from_xml(e, calendar)}
    end

    # Google XMl representation of an evetn object.
    #
    def to_xml
      unless quickadd
        "<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gd='http://schemas.google.com/g/2005'>
          <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/g/2005#event'></category>
          <title type='text'>#{title}</title>
          <content type='text'>#{content}</content>
          <gd:transparency value='http://schemas.google.com/g/2005#event.opaque'></gd:transparency>
          <gd:eventStatus value='http://schemas.google.com/g/2005#event.confirmed'></gd:eventStatus>
          <gd:where valueString=\"#{where}\"></gd:where>
          <gd:when startTime=\"#{start_time}\" endTime=\"#{end_time}\"></gd:when>
         </entry>"
      else
        %Q{<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gCal='http://schemas.google.com/gCal/2005'>
            <content type="html">#{content}</content>
            <gCal:quickadd value="true"/>
          </entry>}
      end
    end

    # String representation of an event object.
    #
    def to_s
      s = "#{title} (#{self.id})\n\t#{start_time}\n\t#{end_time}\n\t#{where}\n\t#{content}"
      s << "\n\t#{quickadd}" if quickadd
      s
    end

    # Saves an event.
    #  Note: If using this on an event you created without using a calendar object,
    #  make sure to set the calendar before calling this method.
    #
    def save
      update_after_save(@calendar.save_event(self))
    end

    # Deletes an event.
    #  Note: If using this on an event you created without using a calendar object,
    #  make sure to set the calendar before calling this method.
    #
    def delete
      @calendar.delete_event(self)
      @id = nil
    end

    protected

    # Create a new event from a google 'entry' xml block.
    #
    def self.new_from_xml(xml, calendar) #:nodoc:
      id          = xml.at_xpath("gCal:uid")['value'].split('@').first
      title       = xml.at_xpath("xmlns:title").content
      content     = xml.at_xpath("xmlns:content").content
      where       = xml.at_xpath("gd:where")['valueString']
      start_time  = xml.at_xpath("gd:when")['startTime']
      end_time    = xml.at_xpath("gd:when")['endTime']
      quickadd    = xml.at_xpath("gCal:quickadd") ? xml.at_xpath("gCal:quickadd")['quickadd'] : nil

      Event.new(:id => id,
                :title => title,
                :content => content,
                :where => where,
                :start_time => start_time,
                :end_time => end_time,
                :calendar => calendar,
                :raw_xml => xml,
                :quickadd => quickadd)
    end

    # Set the ID after google assigns it (only necessary when we are creating a new event)
    #
    def update_after_save(respose) #:nodoc:
      return if @id && @id != ''

      xml = Nokogiri::XML(respose.body).at_xpath("//xmlns:entry")
      @id = xml.at_xpath("gCal:uid")['value'].split('@').first
      @raw_xml = xml
    end

  end
end