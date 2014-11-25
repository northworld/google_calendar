require 'helper'

class TestGoogleCalendar < Minitest::Test
  include Google

  context "When connected" do

    setup do
      @client_mock = mock('Faraday::Response')
      @client_mock.stubs(:body).returns(get_mock_body('successful_login.json'))
      @client_mock.stubs(:finish).returns('')
      @client_mock.stubs(:status).returns(200)
      Faraday::Response.stubs(:new).returns(@client_mock)

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
        events = @calendar.find_events_in_range(start_min, start_max)
      end

      should "find future events" do
        now = Time.now.utc
        Time.stubs(:now).returns(now)
        formatted_time = now.strftime("%FT%TZ")
        @calendar.expects(:event_lookup).with("?timeMin=#{formatted_time}&orderBy=startTime&maxResults=25&singleEvents=true")
        events = @calendar.find_future_events()
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
        assert_equal @calendar.find_event_by_id('1234'), nil
      end

      should "create an event with block" do
        @client_mock.stubs(:body).returns( get_mock_body("create_event.json") )

        event = @calendar.create_event do |e|
          e.title = 'New Event'
          e.start_time = Time.now + (60 * 60)
          e.end_time = Time.now + (60 * 60 * 2)
          e.description = "A new event"
          e.location = "Joe's House"
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
        assert_equal e.to_s, "Event Id '#{e.id}'\n\tTitle: #{e.title}\n\tStarts: #{e.start_time}\n\tEnds: #{e.end_time}\n\tLocation: #{e.location}\n\tDescription: #{e.description}\n\n"
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
          @event = Event.new(:start_time => "2012-03-31", :end_time => "2012-04-03")
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

        correct_json = "{ \"summary\": \"Go Swimming\", \"description\": \"The polar bear plunge\", \"location\": \"In the arctic ocean\", \"start\": { \"dateTime\": \"#{@event.start_time}\" }, \"end\": { \"dateTime\": \"#{@event.end_time}\" }, \"attendees\": [{ \"displayName\": \"Some A One\", \"email\": \"some.a.one@gmail.com\", \"responseStatus\": \"tentative\" },{ \"displayName\": \"Some B One\", \"email\": \"some.b.one@gmail.com\", \"responseStatus\": \"tentative\" }], \"reminders\": { \"useDefault\": false,\"overrides\": [{ \"method\": \"popup\", \"minutes\": 10 }] } }"
        assert_equal @event.to_json.gsub("\n", "").gsub(/\s+/, ' '), correct_json
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
  end

  protected

  def get_mock_body(name)
    File.open(@@mock_path + '/' + name).read
  end

end
