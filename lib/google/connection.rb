require "addressable/uri"
require 'google/net/https'

module Google

  # This is a utility class that performs all of the
  # communication with the google calendar api.
  #
  class Connection
    # set the username, password, auth_url, app_name, and login.
    #
    def initialize(params)
      @username = params[:username]
      @password = params[:password]
      @auth_url = params[:auth_url] || "https://www.google.com/accounts/ClientLogin"
      @app_name = params[:app_name] || "northworld.com-googlecalendar-integration"

      login()
    end

    # login to the google calendar and grab an auth token.
    #
    def login()
      content = {
        'Email' => @username,
        'Passwd' => @password,
        'source' => @app_name,
        'accountType' => 'HOSTED_OR_GOOGLE',
        'service' => 'cl'}

      response = send(Addressable::URI.parse(@auth_url), :post_form, content)

      raise HTTPRequestFailed unless response.kind_of? Net::HTTPSuccess

      @token = response.body.split('=').last
      @headers = {
         'Authorization' => "GoogleLogin auth=#{@token}",
         'Content-Type'  => 'application/atom+xml'
       }
       @update_header = @headers.clone
       @update_header["If-Match"] = "*"
    end

    # send a request to google.
    #
    def send(uri, method, content = '', redirect_count = 10)
      raise HTTPTooManyRedirections if redirect_count == 0

      set_session_if_necessary(uri)

      http = (uri.scheme == 'https' ? Net::HTTPS.new(uri.host, uri.inferred_port) : Net::HTTP.new(uri.host, uri.inferred_port))

      case method
      when :delete
        # puts "in delete: #{uri.to_s}"
        request = Net::HTTP::Delete.new(uri.to_s, @update_header)
      when :get
        # puts "in get: #{uri.to_s}"
        request = Net::HTTP::Get.new(uri.to_s, @headers)
      when :post_form
        # puts "in post_form: #{uri.to_s}"
        request = Net::HTTP::Post.new(uri.to_s, @headers)
        request.set_form_data(content)
      when :post
        # puts "in post: #{uri.to_s}\n#{content}"
        request = Net::HTTP::Post.new(uri.to_s, @headers)
        request.body = content
      when :put
        # puts "in put: #{uri.to_s}\n#{content}"
        request = Net::HTTP::Put.new(uri.to_s, @update_header)
        request.body = content
      end

      response =  http.request(request)

      # recurse if necessary.
      if response.kind_of? Net::HTTPRedirection
        response = send(Addressable::URI.parse(response['location']), method, content, redirect_count - 1)
      end

      # Raise the appropiate error if necessary.
      if response.kind_of? Net::HTTPForbidden
        raise HTTPAuthorizationFailed, response.body

      elsif response.kind_of? Net::HTTPBadRequest
        raise HTTPRequestFailed, response.body

      elsif response.kind_of? Net::HTTPNotFound
        raise HTTPNotFound, response.body
      end

      return response
    end

    protected

    def set_session_if_necessary(uri) #:nodoc:
      # only extract the session if we don't already have one.
      @session_id = uri.query_values['gsessionid'] if @session_id == nil && uri.query

      if @session_id
        uri.query ||= ''
        uri.query_values = uri.query_values.merge({'gsessionid' => @session_id})
      end
    end

  end

end