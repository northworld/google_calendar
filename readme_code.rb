#
# Uncomment the LOAD_PATH lines if you want to run against the 
# local version of the gem.
#
# $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
# $LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'google_calendar'

# Create an instance of the calendar.
cal = Google::Calendar.new(:client_id     => YOUR_CLIENT_ID, 
                           :client_secret => YOUR_SECRET,
                           :calendar      => YOUR_CALENDAR_ID,
                           :redirect_url  => "urn:ietf:wg:oauth:2.0:oob" # this is what Google uses for 'applications'
                           )

puts "Do you already have a refresh token? (y/n)"
has_token = $stdin.gets.chomp

if has_token.downcase != 'y'

  # A user needs to approve access in order to work with their calendars.
  puts "Visit the following web page in your browser and approve access."
  puts cal.authorize_url
  puts "\nCopy the code that Google returned and paste it here:"

  # Pass the ONE TIME USE access code here to login and get a refresh token that you can use for access from now on.
  refresh_token = cal.login_with_auth_code( $stdin.gets.chomp )

  puts "\nMake sure you SAVE YOUR REFRESH TOKEN so you don't have to prompt the user to approve access again."
  puts "your refresh token is:\n\t#{refresh_token}\n"
  puts "Press return to continue"
  $stdin.gets.chomp

else

  puts "Enter your refresh token"
  refresh_token = $stdin.gets.chomp
  cal.login_with_refresh_token(refresh_token)

  # Note: You can also pass your refresh_token to the constructor and it will login at that time.

end

event = cal.create_event do |e|
  e.title = 'A Cool Event'
  e.start_time = Time.now
  e.end_time = Time.now + (60 * 60) # seconds * min
end

puts event

event = cal.find_or_create_event_by_id(event.id) do |e|
  e.title = 'An Updated Cool Event'
  e.end_time = Time.now + (60 * 60 * 2) # seconds * min * hours
end

puts event

# All events
puts cal.events

# Query events
puts cal.find_events('your search string')