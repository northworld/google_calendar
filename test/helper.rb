require 'simplecov'
SimpleCov.start

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require "minitest/autorun"
require 'minitest/reporters'
require 'shoulda/context'
require 'mocha/setup'
require 'faraday'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'google_calendar'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class Minitest::Test
  @@mock_path = File.expand_path(File.join(File.dirname(__FILE__), 'mocks'))
end
