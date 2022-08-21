# File contains the http communication related functions for talking to the
# KM200 device. They are implemented as module-functions of Ruby module Km200.
#
# We are sending and receiving data via HTTP GET and POST in the body of the
# HTTP response (for GET) or request (for POST).

require 'net/http'

module Km200
  # Build a hash setting the user agent in http header.
  def self.http_agent
    {'User-Agent' => 'TeleHeater'}
  end

  # Send an HTTP GET request to the Web-KM200 and return the response body.
  # The User Agent is set to 'TeleHeater'.
  def self.http_get(host, path, port = 80)
    http = Net::HTTP.new(host, port)
    http.read_timeout = 10
    http.open_timeout = 10
    http.get(path, http_agent).body
  end

  # Send an HTTP POST request to the Web-KM200 including the given body.
  # The User Agent is set to 'TeleHeater'.
  def self.http_post(host, path, body, port = 80)
    http = Net::HTTP.new(host, port)
    http.read_timeout = 10
    http.open_timeout = 10
    http.post(path, body, http_agent).body
  end
end
