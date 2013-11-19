require 'helper'

class TestGoogleCalendar < Test::Unit::TestCase
  include Google

  context "Connected" do

    setup do
      @http_mock = mock('Net::HTTPResponse')
      @http_mock.stubs(:code => '200', :kind_of? => false, :message => "OK")
      @http_mock.stubs(:kind_of?).with(Net::HTTPSuccess).returns(true)
      @http_mock.stubs(:body).returns(get_mock_body('successful_login.txt'))
      @http_request_mock = mock('Net::HTTPS')
      @http_request_mock.stubs(:set_form_data => '', :request => @http_mock)

      Net::HTTPS.stubs(:new).returns(@http_request_mock)
    end

    context "Login" do

      should "login properly" do
        assert_nothing_thrown do
          Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret')
        end
      end

      should "catch login with invalid credentials" do
        @http_mock.stubs(:kind_of?).with(Net::HTTPForbidden).returns(true)
        @http_mock.stubs(:body).returns('Error=BadAuthentication')
        assert_raise(HTTPAuthorizationFailed) do
          Calendar.new(:username => 'some.one@gmail.com', :password => 'wrong-password')
        end
      end

      should "login properly with an app_name" do
        assert_nothing_thrown do
          Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
          :app_name => 'northworld.com-googlecalendar-integration'
          )
        end
      end

      should "catch login with invalid app_name" do
        @http_mock.stubs(:kind_of?).with(Net::HTTPForbidden).returns(true)
        @http_mock.stubs(:body).returns('Error=BadAuthentication')
        assert_raise(HTTPAuthorizationFailed) do
          Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
          :app_name => 'northworld.com-silly-cal'
          )
        end
      end

      should "login properly with an auth_url" do
        assert_nothing_thrown do
          Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
          :auth_url => "https://www.google.com/accounts/ClientLogin"
          )
        end
      end

      should "catch login with invalid auth_url" do
        @http_mock.stubs(:kind_of?).with(Net::HTTPForbidden).returns(true)
        @http_mock.stubs(:body).returns('Error=BadAuthentication')
        assert_raise(HTTPAuthorizationFailed) do
          Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
          :auth_url => "https://www.google.com/accounts/ClientLogin/waffles"
          )
        end
      end

      should "login properly with a calendar" do
        assert_nothing_thrown do
          Connection.any_instance.stubs(:login)

          #mock calendar list request
          calendar_uri = mock("get calendar uri")
          Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/default/allcalendars/full").once.returns(calendar_uri)
          Connection.any_instance.expects(:send).with(calendar_uri, :get).once.returns(mock("response", :body => get_mock_body('list_calendars.xml')))

          cal = Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
          :calendar => "Little Giants")

          #mock events list request
          events_uri = mock("get events uri")
          Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/rf1c66uld6dgk2t5lh43svev6g%40group.calendar.google.com/private/full").once.returns(events_uri)
          Connection.any_instance.expects(:send).with(events_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('events.xml')))

          cal.events
        end
      end

      should "catch login with invalid calendar" do

        assert_raise(InvalidCalendar) do
          Connection.any_instance.stubs(:login)

          #mock calendar list request
          calendar_uri = mock("get calendar uri")
          Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/default/allcalendars/full").once.returns(calendar_uri)
          Connection.any_instance.expects(:send).with(calendar_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('list_calendars.xml')))

          cal = Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret',
          :calendar => "invalid calendar")

          cal.events
        end
      end

    end # login context

    context "Username and password not provided" do
      context "with a valid public calendar id" do
        should "fetch event data" do
          assert_nothing_thrown do
            cal = Calendar.new(:calendar => 'en.singapore#holiday@group.v.calendar.google.com')

            #mock events list request
            events_uri = mock("get events uri")
            Addressable::URI.expects(:parse).with("https://www.google.com/calendar/feeds/en.singapore%23holiday%40group.v.calendar.google.com/public/full").once.returns(events_uri)
            Connection.any_instance.expects(:send).with(events_uri, :get, anything).once.returns(mock("response", :body => get_mock_body('events.xml')))

            cal.events
          end
        end
      end

      context "without specifying a public calendar id" do
        should "raise error" do
          assert_raise(CalenarIDMissing) do
            Calendar.new(calendar: nil)
          end
        end
      end
    end

    context "Logged on" do
      setup do
        @calendar = Calendar.new(:username => 'some.one@gmail.com', :password => 'super-secret')
      end

      should "reload connection" do
        old_connection = @calendar.connection
        assert_not_equal old_connection, @calendar.reload.connection
      end

      should "find all events" do
        @http_mock.stubs(:body).returns( get_mock_body("events.xml") )
        assert_equal @calendar.events.length, 3
      end

      should "query events" do
        @http_mock.stubs(:body).returns( get_mock_body("query_events.xml") )
        event = @calendar.find_events('Test&gsessionid=12345')
        assert_equal event[0].title, 'Test'
      end

      should "find events in range" do
        start_min = DateTime.new(2011, 2, 1, 11, 1, 1)
        start_max = DateTime.new(2011, 2, 28, 23, 59, 59)
        @calendar.expects(:event_lookup).with('?start-min=2011-02-01T11:01:01&start-max=2011-02-28T23:59:59&recurrence-expansion-start=2011-02-01T11:01:01&recurrence-expansion-end=2011-02-28T23:59:59&orderby=lastmodified&max-results=25')
        events = @calendar.find_events_in_range(start_min, start_max)
      end

      should "return multiple events in range as array" do
        @http_mock.stubs(:body).returns( get_mock_body("events.xml") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
      end
      
      should "return one event in range as array" do
        @http_mock.stubs(:body).returns( get_mock_body("query_events.xml") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
      end
      
      should "return response of no events in range as array" do
        @http_mock.stubs(:body).returns( get_mock_body("empty_events.xml") )
        events = @calendar.events
        assert_equal events.class.to_s, "Array"
      end

      should "find an event by id" do
        @http_mock.stubs(:body).returns( get_mock_body("find_event_by_id.xml") )
        event = @calendar.find_event_by_id('oj6fmpaulbvk9ouoj0lj4v6hio')
        assert_equal event[0].id, 'oj6fmpaulbvk9ouoj0lj4v6hio'
      end

      should "throw NotFound with invalid event id" do
        @http_mock.stubs(:kind_of?).with(Net::HTTPNotFound).returns(true)
        assert_equal @calendar.find_event_by_id('1234'), nil
      end

      should "create an event with block" do
        @http_mock.stubs(:body).returns( get_mock_body("create_event.xml") )

        event = @calendar.create_event do |e|
          e.title = 'New Event'
          e.start_time = Time.now + (60 * 60)
          e.end_time = Time.now + (60 * 60 * 2)
          e.content = "A new event"
          e.where = "Joe's House"
        end

        assert_equal event.title, 'New Event'
      end

      should "create a quickadd event" do
        @http_mock.stubs(:body).returns( get_mock_body("create_quickadd_event.xml") )

        event = @calendar.create_event do |e|
          e.content = "movie tomorrow 23:00 at AMC Van Ness"
          e.quickadd = true
        end

        assert_equal event.content, "movie tomorrow 23:00 at AMC Van Ness"
      end

      should "format create event with ampersand correctly" do
	@http_mock.stubs(:body).returns( get_mock_body("create_event.xml") )

	event = @calendar.create_event do |e|
	  e.title = 'New Event with &'
	  e.start_time = Time.now + (60 * 60)
	  e.end_time = Time.now + (60 * 60 * 2)
	  e.content = "A new event with &"
	  e.where = "Joe's House & Backyard"
	end

	assert_equal event.title, 'New Event with &amp;'
	assert_equal event.content, 'A new event with &amp;'
	assert_equal event.where, "Joe's House &amp; Backyard"
      end

      should "format to_s properly" do
        @http_mock.stubs(:body).returns( get_mock_body("query_events.xml") )
        event = @calendar.find_events('Test')
        assert_equal event[0].to_s, "Test (oj6fmpaulbvk9ouoj0lj4v6hio)\n\t2010-04-08\n\t2010-04-09\n\tAt School\n\t"
      end

      should "update an event by id" do
        @http_mock.stubs(:body).returns( get_mock_body("find_event_by_id.xml") )

        event = @calendar.find_or_create_event_by_id('oj6fmpaulbvk9ouoj0lj4v6hio') do |e|
          e.title = 'New Event Update'
        end

        assert_equal event.title, 'New Event Update'
      end

      should "delete an event" do
        @http_mock.stubs(:body).returns( get_mock_body("create_event.xml") )

        event = @calendar.create_event do |e|
          e.title = 'Delete Me'
        end

        assert_equal event.id, 'b1vq6rj4r4mg85kcickc7iomb0'

        @http_mock.stubs(:body).returns("")
        event.delete
        assert_equal event.id, nil
      end

      should "not redirect forever" do
        @http_mock.stubs(:kind_of?).with(Net::HTTPRedirection).returns(true)
        @http_mock.stubs(:[]).with('location').returns('https://www.google.com')
        assert_raise(HTTPTooManyRedirections) do
          @calendar.events
        end
      end

      should "throw exception on bad request" do
        @http_mock.stubs(:kind_of?).with(Net::HTTPBadRequest).returns(true)
        assert_raise(HTTPRequestFailed) do
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
          assert_equal @event.to_xml["hours"], nil
          assert_not_equal @event.to_xml["minutes"], nil
        end
      end
    end
  end

  def test_https_extension
    assert_nothing_thrown do
      uri = Addressable::URI.parse('https://www.google.com')
      Net::HTTPS.new(uri.host, uri.port)
    end
  end

  protected

  def get_mock_body(name)
    File.open(@@mock_path + '/' + name).read
  end

end
