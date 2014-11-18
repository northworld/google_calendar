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

      # should "catch login with invalid credentials" do
      #   @http_mock.stubs(:kind_of?).with(Net::HTTPForbidden).returns(true)
      #   @http_mock.stubs(:body).returns('Error=BadAuthentication')
      #   assert_raises(HTTPAuthorizationFailed) do
      #     Calendar.new(:username => 'some.one@gmail.com', :password => 'wrong-password')
      #   end
      # end

      # should "login properly with an app_name" do
      #   assert_nothing_thrown do
      #     Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :app_name => 'northworld.com-googlecalendar-integration'
      #     )
      #   end
      # end

      # should "catch login with invalid app_name" do
      #   @http_mock.stubs(:kind_of?).with(Net::HTTPForbidden).returns(true)
      #   @http_mock.stubs(:body).returns('Error=BadAuthentication')
      #   assert_raises(HTTPAuthorizationFailed) do
      #     Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :app_name => 'northworld.com-silly-cal'
      #     )
      #   end
      # end

      # should "login properly with an auth_url" do
      #   assert_nothing_thrown do
      #     Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :auth_url => "https://www.google.com/accounts/ClientLogin"
      #     )
      #   end
      # end

      # should "catch login with invalid auth_url" do
      #   @http_mock.stubs(:kind_of?).with(Net::HTTPForbidden).returns(true)
      #   @http_mock.stubs(:body).returns('Error=BadAuthentication')
      #   assert_raises(HTTPAuthorizationFailed) do
      #     Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :auth_url => "https://www.google.com/accounts/ClientLogin/waffles"
      #     )
      #   end
      # end

      # should "login properly with a calendar name" do
      #   assert_nothing_thrown do
      #     AuthenticatedConnection.any_instance.stubs(:login)

      #     #mock calendar list request
      #     calendar_uri = mock("get calendar uri")
      #     Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/default/allcalendars/full").once.returns(calendar_uri)
      #     AuthenticatedConnection.any_instance.expects(:send).with(calendar_uri, :get).once.returns(mock("response", :body => get_mock_body('list_calendars.xml')))

      #     cal = Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :calendar => "Little Giants")

      #     #mock events list request
      #     events_uri = mock("get events uri")
      #     Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/rf1c66uld6dgk2t5lh43svev6g%40group.calendar.google.com/private/full").once.returns(events_uri)
      #     AuthenticatedConnection.any_instance.expects(:send).with(events_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('events.xml')))

      #     cal.events
      #   end
      # end

      # should "login properly with a calendar id" do
      #   assert_nothing_thrown do
      #     AuthenticatedConnection.any_instance.stubs(:login)
      #     Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/default/allcalendars/full").never

      #     cal = Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :calendar => "rf1c66uld6dgk2t5lh43svev6g@group.calendar.google.com")

      #     #mock events list request
      #     events_uri = mock("get events uri")
      #     Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/rf1c66uld6dgk2t5lh43svev6g%40group.calendar.google.com/private/full").once.returns(events_uri)
      #     AuthenticatedConnection.any_instance.expects(:send).with(events_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('events.xml')))

      #     cal.events
      #   end
      # end

      # should "catch login with invalid calendar" do

      #   assert_raises(InvalidCalendar) do
      #     AuthenticatedConnection.any_instance.stubs(:login)

      #     #mock calendar list request
      #     calendar_uri = mock("get calendar uri")
      #     Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/default/allcalendars/full").once.returns(calendar_uri)
      #     AuthenticatedConnection.any_instance.expects(:send).with(calendar_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('list_calendars.xml')))

      #     cal = Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
      #     :calendar => "invalid calendar")

      #     cal.events
      #   end
      # end

    end # login context

    context "without credentials" do

    #   context "with a public calendar" do
    #     should "fetch event data" do
    #       skip

    #       # cal = Calendar.new(:calendar => 'en.singapore#holiday@group.v.calendar.google.com')

    #       # #mock events list request
    #       # events_uri = mock("get events uri")
    #       # Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/en.singapore%23holiday%40group.v.calendar.google.com/public/full").once.returns(events_uri)
    #       # Connection.any_instance.expects(:send).with(events_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('events.xml')))

    #       # cal.events

    #     end
    #   end

    #   context "without a public calendar" do
    #     should "raise error" do
    #       skip
    #       # assert_raises(CalenarIDMissing) do
    #       #   Calendar.new(calendar: nil)
    #       # end
    #     end
    #   end
    end

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
        start_min = DateTime.new(2011, 2, 1, 11, 1, 1)
        start_max = DateTime.new(2011, 2, 28, 23, 59, 59)
        @calendar.expects(:event_lookup).with('?start-min=2011-02-01T11%3A01%3A01%2B00%3A00&start-max=2011-02-28T23%3A59%3A59%2B00%3A00&recurrence-expansion-start=2011-02-01T11%3A01%3A01%2B00%3A00&recurrence-expansion-end=2011-02-28T23%3A59%3A59%2B00%3A00&orderby=lastmodified&max-results=25')
        events = @calendar.find_events_in_range(start_min, start_max)
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

    context "reminders" do
      context "reminders array" do
        should "set reminder time" do
          @event = Event.new :reminders => [minutes: 6]
          assert_equal @event.reminders.first[:minutes], 6
        end

        should "use different time scales" do
          @event = Event.new :reminders => [hours: 5]
          assert_equal @event.reminders.first[:hours], 5
        end

        should "set reminder method" do
          @event = Event.new :reminders => [minutes: 6, method: "sms"]
          assert_equal @event.reminders.first[:minutes], 6
          assert_equal @event.reminders.first[:method], "sms"
        end

        should "default to minutes -> hours -> days" do
          @event = Event.new :reminders => [minutes: 6, hours: 8]
          assert_equal @event.reminders.first[:minutes], 6
          assert_equal @event.reminders.first[:hours], 8
        end
      end
    end
  end

  protected

  def get_mock_body(name)
    File.open(@@mock_path + '/' + name).read
  end

end
