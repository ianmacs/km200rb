# File contains functions to find and read the configuration file for this
# library.  The configuration file is a YAML file and contains the KM200's
# IP address (or host name), credentials, etc.
# The path to the configuration file can be given by the client or, if not
# given, two default locations of the configuration file are tried:
# ~/.km200_config.yml and /etc/km200_config.yml.

require 'yaml'

module Km200

    # The following fields are mandatory in the configuration file:
  Config_Required_Fields = [
    'gateway_password', # password from sticker on Web-KM200
    'private_password', # password set by customer in smartphone app
    'host', # IP address or host name of KM200
  ]

  # Load Km200 configuration from YAML file
  def self.load_configfile(filename = nil)
    filename = default_configfilename(filename)
    config = YAML.load_file(filename)
    # Check that required fields are present
    if (config.respond_to?(:[]) == false) ||
       Config_Required_Fields.any? { |field| config[field].nil? }
      raise ("Configfile #{filename} does not contain all required fields." +
             "  Required fields are: #{Config_Required_Fields.join(', ')}")
    end
    config
  end

  Config_Filename_Home = ENV['HOME'] + '/.km200.yml'
  Config_Filename_Etc = '/etc/km200.yml'
  def self.default_configfilename(filename = nil)
    if filename == nil && File.exist?(Config_Filename_Home)
      filename = Config_Filename_Home
    end
    if filename == nil && File.exist?(Config_Filename_Etc)
      filename = Config_Filename_Etc
    end
    if filename == nil || !File.exist?(filename)
      raise Errno::ENOENT.new("No config file found")
    end
    return filename
  end
end
