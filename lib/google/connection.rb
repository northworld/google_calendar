require "addressable/uri"
require 'google/net/https'
require 'cgi'

module Google

  # This is a utility class that performs all of the
  # communication with the google calendar api.
  #
  class Connection
    BASE_URI = "https://www.google.com/calendar/feeds"

    def self.connect params
      if credentials_provided? params[:username], params[:password]
        AuthenticatedConnection.new params
      else
        self.new params
      end
    end

    def initialize(params)
      calendar_name = params[:calendar_name]
      calendar_id = params[:calendar_id]

      raise CalenarIDMissing unless calendar_id
      @events_url = "#{BASE_URI}/#{CGI::escape(calendar_id)}/public/full"
    end

    # send a request to google.
    #
    def send(uri, method, content = '', redirect_count = 10)
      raise HTTPTooManyRedirections if redirect_count == 0

      set_session_if_necessary(uri)

      http = (uri.scheme == 'https' ? Net::HTTPS.new(uri.host, uri.inferred_port) : Net::HTTP.new(uri.host, uri.inferred_port))
      response =  http.request(build_request(uri, method, content))

      # recurse if necessary.
      if response.kind_of? Net::HTTPRedirection
        response = send(Addressable::URI.parse(response['location']), method, content, redirect_count - 1)
      end

      check_for_errors(response)

      return response
    end

    def send_events_request(path_and_query_string, method, content='')
      send(Addressable::URI.parse(@events_url + path_and_query_string), method, content)
    end

    protected

    # Check to see if we are using a session and extract it's values if required.
    # 
    def set_session_if_necessary(uri) #:nodoc:
      # only extract the session if we don't already have one.
      @session_id = uri.query_values['gsessionid'] if @session_id == nil && uri.query

      if @session_id
        uri.query ||= ''
        uri.query_values = uri.query_values.merge({'gsessionid' => @session_id})
      end
    end

    # Construct the appropriate request object.
    #
    def build_request(uri, method, content) #:nodoc
      case method
      when :delete
        request = Net::HTTP::Delete.new(uri.to_s, @update_header)

      when :get
        request = Net::HTTP::Get.new(uri.to_s, @headers)

      when :post_form
        request = Net::HTTP::Post.new(uri.to_s, @headers)
        request.set_form_data(content)

      when :post
        request = Net::HTTP::Post.new(uri.to_s, @headers)
        request.body = content

      when :put
        request = Net::HTTP::Put.new(uri.to_s, @update_header)
        request.body = content
      end # case

      return request
    end

    # Check for common HTTP Errors and raise the appropriate response.
    #
    def check_for_errors(response) #:nodoc
      if response.kind_of? Net::HTTPForbidden
        raise HTTPAuthorizationFailed, response.body

      elsif response.kind_of? Net::HTTPBadRequest
        raise HTTPRequestFailed, response.body

      elsif response.kind_of? Net::HTTPNotFound
        raise HTTPNotFound, response.body
      end
    end

    private

    def self.credentials_provided? username, password
      blank = /[^[:space:]]/
      !(username !~ blank) && !(password !~ blank)
    end

  end
end
