require 'helper'

class TestGoogleCalendar < Minitest::Test
  include Google

  context "When connected" do

    setup do
      @client_mock = setup_mock_client

      @client_id = "671053090364-ntifn8rauvhib9h3vnsegi6dhfglk9ue.apps.googleusercontent.com"
      @client_secret = "roBgdbfEmJwPgrgi2mRbbO-f"
      @refresh_token = "1/eiqBWx8aj-BsdhwvlzDMFOUN1IN_HyThvYTujyksO4c"
      @calendar_id = "klei8jnelo09nflqehnvfzipgs@group.calendar.google.com"
      @access_token = 'ya29.hYjPO0uHt63uWr5qmQtMEReZEvILcdGlPCOHDy6quKPyEQaQQvqaVAlLAVASaRm_O0a7vkZ91T8xyQ'

      @calendar = Calendar.new(:client_id => @client_id, :client_secret => @client_secret, :redirect_url => "urn:ietf:wg:oauth:2.0:oob", :refresh_token => @refresh_token, :calendar => @calendar_id)

    end

    context "a calendar" do

      should "generate auth url" do
        assert_equal @calendar.authorize_url.to_s, 'https://accounts.google.com/o/oauth2/auth?access_type=offline&client_id=671053090364-ntifn8rauvhib9h3vnsegi6dhfglk9ue.apps.googleusercontent.com&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code&scope=https://www.googleapis.com/auth/calendar'
      end

      should "login with auth code" do
        @client_mock.stubs(:body).returns( get_mock_body("login_with_auth_code_success.json") )
        @calendar.login_with_auth_code('4/QzBU-n6GXnHUkorG0fiu6AhoZtIjW53qKLOREiJWFpQ.wn0UfiyaDlEfEnp6UAPFm0EazsV1kwI')
        assert_equal @calendar.auth_code, nil # the auth_code is discarded after it is used.
        assert_equal @calendar.access_token, @access_token
        assert_equal @calendar.refresh_token, '1/aJUy7pQzc4fUMX89BMMLeAfKcYteBKRMpQvf4fQFX0'
      end

      should "login with refresh token" do
        # no refresh_token specified
        cal = Calendar.new(:client_id => @client_id, :client_secret => @client_secret, :redirect_url => "urn:ietf:wg:oauth:2.0:oob", :calendar => @calendar_id)
        @client_mock.stubs(:body).returns( get_mock_body("login_with_refresh_token_success.json") )
        cal.login_with_refresh_token(@refresh_token)
        assert_equal @calendar.access_token, @access_token
      end

      should "catch login with invalid credentials" do
        @client_mock.stubs(:status).returns(403)
        @client_mock.stubs(:body).returns( get_mock_body("403.json") )
        assert_raises(HTTPAuthorizationFailed) do
          Calendar.new(:client_id => 'abadid', :client_secret => 'abadsecret', :redirect_url => "urn:ietf:wg:oauth:2.0:oob", :refresh_token => @refresh_token, :calendar => @calendar_id)
        end
      end

      should "catch login with missing credentials" do
        assert_raises(ArgumentError) do
        @client_mock.stubs(:status).returns(401)
        @client_mock.stubs(:body).returns( get_mock_body("401.json") )
          Calendar.new()
        end
      end

      should "accept a connection to re-use" do
        @client_mock.stubs(:body).returns( get_mock_body("events.json") )
        reusable_connection = mock('Google::Connection')
        reusable_connection.expects(:send).returns(@client_mock)

        calendar = Calendar.new({:calendar => @calendar_id}, reusable_connection)
        calendar.events
      end

    end # login context

    context "and logged in" do
      setup do
        @calendar = Calendar.new(:client_id => @client_id, :client_secret => @client_secret, :redirect_url => "urn:ietf:wg:oauth:2.0:oob", :refresh_token => @refresh_token, :calendar => @calendar_id)
      end

      should "find all events" do
        @client_mock.stubs(:body).returns( get_mock_body("events.json") )
        assert_equal @calendar.events.length, 3
      end

      should "query events" do
        @client_mock.stubs(:body).returns( get_mock_body("query_events.json") )
        event = @calendar.find_events('Test&gsessionid=12345')
        assert_equal event[0].title, 'Test Event'
      end

      should "find events in range" do
        now = Time.now.utc
        Time.stubs(:now).returns(now)
        start_min = now
        start_max = (now + 60*60*24)
        @calendar.expects(:event_lookup).with("?timeMin=#{start_min.strftime("%FT%TZ")}&timeMax=#{start_max.strftime("%FT%TZ")}&orderBy=startTime&maxResults=25&singleEvents=true")
        @calendar.find_events_in_range(start_min, start_max)
      end

      should "find events with shared extended property" do
        @calendar.expects(:event_lookup).with("?sharedExtendedProperty=p%3Dv&sharedExtendedProperty=q%3Dw&orderBy=startTime&maxResults=25&singleEvents=true")
        @calendar.find_events_by_extended_properties({'shared' => {'p' => 'v', 'q' => 'w'}})
      end

      should "find events with shared extended property in range" do
        now = Time.now.utc
        Time.stubs(:now).returns(now)
        start_min = now
        start_max = (now + 60*60*24)
        @calendar.expects(:event_lookup).with("?sharedExtendedProperty=p%3Dv&orderBy=startTime&maxResults=25&singleEvents=true&timeMin=#{start_min.strftime("%FT%TZ")}&timeMax=#{start_max.strftime("%FT%TZ")}")
        @calendar.find_events_by_extended_properties_in_range({'shared' => {'p' => 'v'}}, start_min, start_max)
      end

      should "find future events" do
        now = Time.now.utc
        Time.stubs(:now).returns(now)
        formatted_time = now.strftime("%FT%TZ")
        @calendar.expects(:event_lookup).with("?timeMin=#{formatted_time}&orderBy=startTime&maxResults=25&singleEvents=true")
        @calendar.find_future_events()
      end

      should "find future events with query" do
        now = Time.now.utc
        Time.stubs(:now).returns(now)
        formatted_time = now.strftime("%FT%TZ")
        @calendar.expects(:event_lookup).with("?timeMin=#{formatted_time}&orderBy=startTime&maxResults=25&singleEvents=true&q=Test")
        @calendar.find_future_events({max_results: 25, order_by: :startTime, query: 'Test'})
      end

      should "return multiple events in range as array" do
        @client_mock.stubs(:body).returns( get_mock_body("events.json") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
      end

      should "return one event in range as array" do
        @client_mock.stubs(:body).returns( get_mock_body("query_events.json") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
      end

      should "return one event in range as array from cancelled data" do
        @client_mock.stubs(:body).returns( get_mock_body("cancelled_events.json") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
      end

      should "return response of no events in range as array" do
        @client_mock.stubs(:body).returns( get_mock_body("empty_events.json") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
        assert_equal events, []
      end

      should "find an event by id" do
        @client_mock.stubs(:body).returns( get_mock_body("find_event_by_id.json") )
        event = @calendar.find_event_by_id('fhru34kt6ikmr20knd2456l08n')
        assert_equal event[0].id, 'fhru34kt6ikmr20knd2456l08n'
      end

      should "throw NotFound with invalid event id" do
        @client_mock.stubs(:status).returns(404)
        @client_mock.stubs(:body).returns( get_mock_body("404.json") )
        assert_equal @calendar.find_event_by_id('1234'), []
      end

      should "create an event with block" do
        @client_mock.stubs(:body).returns( get_mock_body("create_event.json") )

        event = @calendar.create_event do |e|
          e.title = 'New Event'
          e.start_time = Time.now + (60 * 60)
          e.end_time = Time.now + (60 * 60 * 2)
          e.description = "A new event"
          e.location = "Joe's House"
          e.extended_properties = {'shared' => {'key' => 'value' }}
        end

        assert_equal event.title, 'New Event'
        assert_equal event.id, "fhru34kt6ikmr20knd2456l08n"
      end

      should "find properly parse all day event" do
        @client_mock.stubs(:body).returns( get_mock_body("find__all_day_event_by_id.json") )
        event = @calendar.find_event_by_id('fhru34kt6ikmr20knd2456l10n')
        assert_equal event[0].id, 'fhru34kt6ikmr20knd2456l10n'
        assert_equal event[0].start_time, "2008-09-24T17:30:00Z"
      end

      should "find properly parse missing date event" do
        now = Time.now.utc
        Time.stubs(:now).returns(now)
        formatted_time = now.strftime("%FT%TZ")
        @client_mock.stubs(:body).returns( get_mock_body("missing_date.json") )
        event = @calendar.find_event_by_id('fhru34kt6ikmr20knd2456l12n')
        assert_equal event[0].id, 'fhru34kt6ikmr20knd2456l12n'
        assert_equal event[0].start_time, formatted_time
      end

      should "create a quickadd event" do
        @client_mock.stubs(:body).returns( get_mock_body("create_quickadd_event.json") )

        event = @calendar.create_event do |e|
          e.title = "movie tomorrow 23:00 at AMC Van Ness"
          e.quickadd = true
        end

        assert_equal event.title, "movie tomorrow 23:00 at AMC Van Ness"
        assert_equal event.id, 'fhru34kt6ikmr20knd2456l08n'
      end

      should "format create event with ampersand correctly" do
        @client_mock.stubs(:body).returns( get_mock_body("create_event.json") )

        event = @calendar.create_event do |e|
          e.title = 'New Event with &'
          e.start_time = Time.now + (60 * 60)
          e.end_time = Time.now + (60 * 60 * 2)
          e.description = "A new event with &"
          e.location = "Joe's House & Backyard"
        end

        assert_equal event.title, 'New Event with &'
        assert_equal event.description, 'A new event with &'
        assert_equal event.location, "Joe's House & Backyard"
      end

      should "format to_s properly" do
        @client_mock.stubs(:body).returns( get_mock_body("query_events.json") )
        event = @calendar.find_events('Test')
        e = event[0]
        assert_equal e.to_s, "Event Id '#{e.id}'\n\tStatus: #{e.status}\n\tTitle: #{e.title}\n\tStarts: #{e.start_time}\n\tEnds: #{e.end_time}\n\tLocation: #{e.location}\n\tDescription: #{e.description}\n\tColor: #{e.color_id}\n\n"
      end

      should "update an event by id" do
        @client_mock.stubs(:body).returns( get_mock_body("find_event_by_id.json") )

        event = @calendar.find_or_create_event_by_id('t00jnpqc08rcabi6pa549ttjlk') do |e|
          e.title = 'New Event Update'
        end

        assert_equal event.title, 'New Event Update'
      end

      should "delete an event" do
        @client_mock.stubs(:body).returns( get_mock_body("create_event.json") )

        event = @calendar.create_event do |e|
          e.title = 'Delete Me'
        end

        assert_equal event.id, 'fhru34kt6ikmr20knd2456l08n'

        @client_mock.stubs(:body).returns('')
        event.delete
        assert_equal event.id, nil
      end

      should "throw exception on bad request" do
        @client_mock.stubs(:status).returns(400)
        assert_raises(HTTPRequestFailed) do
          @calendar.events
        end
      end

      should "create event when id is NIL" do
        @client_mock.stubs(:body).returns( get_mock_body("find_event_by_id.json") )

        event = @calendar.find_or_create_event_by_id(NIL) do |e|
          e.title = 'New Event Update when id is NIL'
        end

        assert_equal event.title, 'New Event Update when id is NIL'
      end

      should "provide the calendar summary" do
        @client_mock.stubs(:body).returns( get_mock_body("events.json") )
        @calendar.events
        assert_equal 'My Events Calendar', @calendar.summary
      end

    end # Logged on context

  end # Connected context

  context "Event instance methods" do
    context "#all_day?" do
      context "when the event is marked as All Day in google calendar" do
        should "be true" do
          @event = Event.new(:start_time => "2012-03-31", :end_time => "2012-04-01")
          assert @event.all_day?
        end
      end
      context "when the event is marked as All Day in google calendar and have more than one day" do
        should "be true" do
          @event = Event.new(:start_time => "2012-03-31", :end_time => "2012-04-03", :all_day => "2012-03-31")
          assert @event.all_day?
        end
      end
      context "when the event is not marked as All Day in google calendar and has duration of one whole day" do
        should "be false" do
          @event = Event.new(:start_time => "2012-03-27T10:00:00.000-07:00", :end_time => "2012-03-28T10:00:00.000-07:00")
          assert !@event.all_day?
        end
      end
      context "when the event is not an all-day event" do
        should "be false" do
          @event = Event.new(:start_time => "2012-03-27T10:00:00.000-07:00", :end_time => "2012-03-27T10:30:00.000-07:00")
          assert !@event.all_day?
        end
      end
    end

    context "#all_day=" do
      context "sets the start and end time to the appropriate values for an all day event on that day" do
        should "set the start time" do
          @event = Event.new :all_day => Time.parse("2012-05-02 12:24")
          assert_equal @event.start_time, "2012-05-02"
        end
        should "set the end time" do
          @event = Event.new :all_day => Time.parse("2012-05-02 12:24")
          assert_equal @event.end_time, "2012-05-03"
        end
        should "be able to handle strings" do
          @event = Event.new :all_day => "2012-05-02 12:24"
          assert_equal @event.start_time, "2012-05-02"
          assert_equal @event.end_time, "2012-05-03"
        end
      end
    end

    context "#creator_name" do
      should "include name" do
        event = Event.new :creator => {'displayName' => 'Someone', 'email' => 'someone@example.com'}
        assert_equal 'Someone', event.creator_name
      end
    end

    context "transparency" do
      should "be transparent" do
        @event = Event.new(:transparency => true)
        assert @event.transparent?
      end

      should "be opaque?" do
        @event = Event.new(:transparency => false)
        assert @event.opaque?
      end
    end

    context "event json" do
      should "be correct format" do
        now = Time.now
        @event = Event.new
        @event.start_time = now
        @event.end_time = now + (60 * 60)
        @event.title = "Go Swimming"
        @event.description = "The polar bear plunge"
        @event.location = "In the arctic ocean"
        @event.transparency = "opaque"
        @event.reminders = { 'useDefault'  => false, 'overrides' => ['minutes' => 10, 'method' => "popup"]}
        @event.attendees = [
                            {'email' => 'some.a.one@gmail.com', 'displayName' => 'Some A One', 'responseStatus' => 'tentative'},
                            {'email' => 'some.b.one@gmail.com', 'displayName' => 'Some B One', 'responseStatus' => 'tentative'}
                          ]
        @event.extended_properties = { 'shared' => { 'key' => 'value' }}
        @event.guests_can_invite_others = false
        @event.guests_can_see_other_guests = false

        expected_structure = {
          "summary" => "Go Swimming",
          "visibility"=>"default",
          "transparency"=>"opaque",
          "description" => "The polar bear plunge",
          "location" => "In the arctic ocean",
          "start" => {"dateTime" => "#{@event.start_time}"},
          "end" => {"dateTime" => "#{@event.end_time}"},
          "attendees" => [
            {"displayName" => "Some A One", "email" => "some.a.one@gmail.com", "responseStatus" => "tentative"},
            {"displayName" => "Some B One", "email" => "some.b.one@gmail.com", "responseStatus" => "tentative"}
          ],
          "reminders" => {"useDefault" => false, "overrides" => [{"method" => "popup", "minutes" => 10}]},
          "extendedProperties" => {"shared" => {'key' => 'value'}},
          "guestsCanInviteOthers" => false,
          "guestsCanSeeOtherGuests" => false
        }
        assert_equal JSON.parse(@event.to_json), expected_structure
      end
    end

    context "reminders" do
      context "reminders hash" do
        should "set reminder time" do
          @event = Event.new(:reminders => { 'useDefault'  => false, 'overrides' => ['minutes' => 6, 'method' => "popup"]})
          assert_equal @event.reminders['overrides'].first['minutes'], 6
        end

        should "use different time scales" do
          @event = Event.new(:reminders => { 'useDefault'  => false, 'overrides' => ['hours' => 6, 'method' => "popup"]})
          assert_equal @event.reminders['overrides'].first['hours'], 6
        end

        should "set reminder method" do
          @event = Event.new(:reminders => { 'useDefault'  => false, 'overrides' => ['minutes' => 6, 'method' => "sms"]})
          assert_equal @event.reminders['overrides'].first['minutes'], 6
          assert_equal @event.reminders['overrides'].first['method'], 'sms'
        end
      end
    end

    context "at recurring events" do
      should "create json in correct format" do
        now = Time.now
        @event = Event.new
        @event.start_time = now
        @event.end_time = now + (60 * 60)
        @event.title = "Go Swimming"
        @event.description = "The polar bear plunge"
        @event.location = "In the arctic ocean"
        @event.transparency = "opaque"
        @event.reminders = { 'useDefault'  => false, 'overrides' => ['minutes' => 10, 'method' => "popup"]}
        @event.attendees = [
                            {'email' => 'some.a.one@gmail.com', 'displayName' => 'Some A One', 'responseStatus' => 'tentative'},
                            {'email' => 'some.b.one@gmail.com', 'displayName' => 'Some B One', 'responseStatus' => 'tentative'}
                          ]
        @event.recurrence = {freq: "monthly", count: "5", interval: "2"}
        @event.extended_properties = {'shared' => {'key' => 'value'}}
        @event.guests_can_invite_others = false
        @event.guests_can_see_other_guests = false
        require 'timezone_parser'
        expected_structure = {
          "summary" => "Go Swimming",
          "visibility"=>"default",          
          "transparency"=>"opaque",
          "description" => "The polar bear plunge",
          "location" => "In the arctic ocean",
          "start" => {"dateTime" => "#{@event.start_time}", "timeZone" => "#{TimezoneParser::getTimezones(Time.now.getlocal.zone).last}"},
          "end" => {"dateTime" => "#{@event.end_time}", "timeZone" => "#{TimezoneParser::getTimezones(Time.now.getlocal.zone).last}"},
          "recurrence" => ["RRULE:FREQ=MONTHLY;COUNT=5;INTERVAL=2"],
          "attendees" => [
            {"displayName" => "Some A One", "email" => "some.a.one@gmail.com", "responseStatus" => "tentative"},
            {"displayName" => "Some B One", "email" => "some.b.one@gmail.com", "responseStatus" => "tentative"}
          ],
          "reminders" => {"useDefault" => false, "overrides" => [{"method" => "popup", "minutes"=>10}]},
          "extendedProperties" => {"shared" => {'key' => 'value'}},
          "guestsCanInviteOthers" => false,
          "guestsCanSeeOtherGuests" => false
        }
        assert_equal JSON.parse(@event.to_json), expected_structure
      end

      should "parse recurrence rule strings corectly" do
        rrule = ["RRULE:FREQ=MONTHLY;INTERVAL=2;BYDAY=-1MO"]
        correct_hash = {"freq" => "monthly", "interval" => "2", "byday" => "-1mo"}
        assert_equal correct_hash.inspect, Event.parse_recurrence_rule(rrule).inspect

        rrule = ["RRULE:FREQ=MONTHLY;UNTIL=20170629T080000Z;INTERVAL=6"]
        correct_hash = {"freq" =>  "monthly", "until" => "20170629t080000z", "interval" => "6"}
        assert_equal correct_hash.inspect, Event.parse_recurrence_rule(rrule).inspect

        rrule = ["RRULE:FREQ=WEEKLY;BYDAY=MO,TH"]
        correct_hash = {"freq" => "weekly", "byday" => "mo,th"}
        assert_equal correct_hash.inspect, Event.parse_recurrence_rule(rrule).inspect
      end
    end
  end

  context "a calendar list" do

    setup do
      @client_mock = setup_mock_client

      @client_id = "671053090364-ntifn8rauvhib9h3vnsegi6dhfglk9ue.apps.googleusercontent.com"
      @client_secret = "roBgdbfEmJwPgrgi2mRbbO-f"
      @refresh_token = "1/eiqBWx8aj-BsdhwvlzDMFOUN1IN_HyThvYTujyksO4c"

      @calendar_list = Google::CalendarList.new(
        :client_id => @client_id,
        :client_secret => @client_secret,
        :redirect_url => "urn:ietf:wg:oauth:2.0:oob",
        :refresh_token => @refresh_token
      )

      @client_mock.stubs(:body).returns(get_mock_body("find_calendar_list.json"))
    end

    should "find all calendars" do
      entries = @calendar_list.fetch_entries
      assert_equal entries.length, 3
      assert_equal entries.map(&:class).uniq, [CalendarListEntry]
      assert_equal entries.map(&:id), ["initech.com_ed493d0a9b46ea46c3a0d48611ce@resource.calendar.google.com", "initech.com_db18a4e59c230a5cc5d2b069a30f@resource.calendar.google.com", "bob@initech.com"]
    end

    should "set the calendar list entry parameters" do
      entry = @calendar_list.fetch_entries.find {|list_entry| list_entry.id == "bob@initech.com" }

      assert_equal entry.summary, "Bob's Calendar"
      assert_equal entry.time_zone, "Europe/London"
      assert_equal entry.access_role, "owner"
      assert_equal entry.primary?, true
    end

    should "accept a connection to re-use" do
      reusable_connection = mock('Google::Connection')
      reusable_connection.expects(:send).returns(@client_mock)

      calendar_list = CalendarList.new({}, reusable_connection)
      calendar_list.fetch_entries
    end

    should "return entries which can create calendars" do
      entry = @calendar_list.fetch_entries.first
      calendar = entry.to_calendar

      assert_equal calendar.class, Calendar
      assert_equal calendar.id, entry.id
      assert_equal calendar.connection, @calendar_list.connection
    end

  end

  context "a freebusy query" do

    setup do
      @client_mock = setup_mock_client

      @client_id = "671053090364-ntifn8rauvhib9h3vnsegi6dhfglk9ue.apps.googleusercontent.com"
      @client_secret = "roBgdbfEmJwPgrgi2mRbbO-f"
      @refresh_token = "1/eiqBWx8aj-BsdhwvlzDMFOUN1IN_HyThvYTujyksO4c"

      @freebusy = Google::Freebusy.new(
        :client_id => @client_id,
        :client_secret => @client_secret,
        :redirect_url => "urn:ietf:wg:oauth:2.0:oob",
        :refresh_token => @refresh_token
      )

      @client_mock.stubs(:body).returns(get_mock_body("freebusy_query.json"))

      @calendar_ids = ['busy-calendar-id', 'not-busy-calendar-id']
      @start_time = Time.new(2015, 3, 6, 0, 0, 0)
      @end_time = Time.new(2015, 3, 6, 23, 59, 59)
    end

    should "return a hash with keys of the supplied calendar ids" do
      assert_equal ['busy-calendar-id', 'not-busy-calendar-id'], @freebusy.query(@calendar_ids, @start_time, @end_time).keys
    end

    should "returns the busy times for each calendar supplied" do
      freebusy_result = @freebusy.query(@calendar_ids, @start_time, @end_time)

      assert_equal ({'start' => '2015-03-06T10:00:00Z', 'end' => '2015-03-06T11:00:00Z' }), freebusy_result['busy-calendar-id'].first
      assert_equal ({'start' => '2015-03-06T11:30:00Z', 'end' => '2015-03-06T11:30:00Z' }), freebusy_result['busy-calendar-id'].last
      assert_equal [], freebusy_result['not-busy-calendar-id']
    end
  end

  protected

  def get_mock_body(name)
    File.open(@@mock_path + '/' + name).read
  end

  def setup_mock_client
    client = mock('Faraday::Response')
    client.stubs(:finish).returns('')
    client.stubs(:status).returns(200)
    client.stubs(:headers).returns({'Content-type' => 'application/json; charset=utf-8'})
    client.stubs(:body).returns(get_mock_body('successful_login.json'))
    Faraday::Response.stubs(:new).returns(client)
    client
  end

end
