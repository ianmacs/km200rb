# File contains the http communication related functions for talking to the
# KM200 device. They are implemented as module-functions of Ruby module Km200.
#
# We are sending and receiving data via HTTP GET and POST in the body of the
# HTTP response (for GET) or request (for POST).

require 'net/http'
require_relative '../lib/km200_crypto.rb'
require "set"

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

  # Class for handling the web communication with Km200 including crypto.
  class Webclient
    # Initialize with the config file. If nil is given, the default config file
    # locations are tried.
    def initialize(configfile = nil)
      @config = Km200.load_configfile(configfile)
      @crypto = Km200::Crypto.new(configfile)
      @host = @config['host']
    end
    
    # Send an HTTP GET request to the Web-KM200 and return the decrypted json as string.
    def read_json(path)
      base64 = Km200.http_get(@host, path)
      @crypto.decrypt(base64)
    end
    
    # Send an HTTP GET request to the Web-KM200 and from the decrypted json, return:
    # * The value field for numeric and string values.
    # * The switchPoints array for switch programs.
    # * A set of paths for directories.
    # * The parsed json object for other data types.
    def read_data(path)
      json_str = read_json(path)
      json = JSON.parse(json_str)
      case json['type']
      when 'floatValue'
        json['value']
      when 'stringValue'
        json['value']
      when 'switchProgram'
        json['switchPoints']
      when 'refEnum'
        json['references'].map { |ref| ref['id'] }.to_set
      else
        json
      end
    end

    # Send an HTTP POST request to the Web-KM200 including the given data after
    # encrypting it.  The json data is expected as string.
    def write_json(path, json)
      base64 = @crypto.encrypt(json)
      Km200.http_post(@host, path, base64)
    end
  end
end
