module Google
  class PublicCalendar < Calendar
    def initialize(params)
      raise Google::CalenarIDMissing unless params[:calendar]
      super
    end

    protected

    def events_url
      "https://www.google.com/calendar/feeds/#{calendar_id}/public/full"
    end
  end
end
