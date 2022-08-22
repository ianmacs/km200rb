# Package for unit tests
require 'test/unit'
require 'json'
require_relative '../lib/km200_webclient.rb'
require_relative '../lib/km200_crypto.rb'


# Tests in this fixture connect to a real KM200 device and therefore need a
# configuration file with working credentials.  If there is no credentials
# file, the tests silently succeed without testing anything.
class TestKm200Webclient < Test::Unit::TestCase
  def setup
    @file = if File.exist?('./real-device-credentials.yml')
      './real-device-credentials.yml'
    end
    begin
      @config = Km200.load_configfile(@file)
      @crypto = Km200::Crypto.new(@file)
      @host = @config['host']
    rescue # ignore errors, tests will skip testing
      $stderr.puts 'No configuration found, not testing on real device'
    end
  end

  def test_http_get
    expected_json = '{"id":"/gateway/versionHardware","type":"stringValue",' +
                    '"writeable":0,"recordable":0,"value":"iCom_Low_NSC_v1"}'
    if @crypto && @config && @host
      # Test that http_get returns the expected response body.
      ciphertext = Km200.http_get(@host, '/gateway/versionHardware')
      actual_json = @crypto.decrypt(ciphertext)
      assert_equal(expected_json, actual_json)
    end
  end

  def test_http_post
    if @crypto && @config && @host # skip tests if no credentials available

      # In order to test http_post, we need to know the value of the
      # some setting that we can then change for the test and then change back.
      # Use /heatingCircuits/hc1/temperatureLevels/eco for this.
      original_base64 = Km200.http_get(@host, '/heatingCircuits/hc1/temperatureLevels/eco')
      original_json = @crypto.decrypt(original_base64)
      original_value = JSON.parse(original_json)['value']

      # Change value to 5C, except if it was 5C already, then change to 0C.
      new_value = (original_value == 5) ? 0 : 5
      new_json = '{"value":%d}' % new_value
      new_base64 = @crypto.encrypt(new_json)
      $stderr.puts "new base64: #{new_base64}"
      Km200.http_post(@host, '/heatingCircuits/hc1/temperatureLevels/eco', new_base64)

      # Reread value and check that it is now changed.
      altered_base64 = Km200.http_get(@host, '/heatingCircuits/hc1/temperatureLevels/eco')
      altered_json = @crypto.decrypt(altered_base64)
      altered_value = JSON.parse(altered_json)['value']
      assert_equal(new_value, altered_value)
      assert_not_equal(original_value, altered_value)

      # Change value back to original value.
      reset_json = '{"value":%.1f}' % original_value
      reset_base64 = @crypto.encrypt(reset_json)
      Km200.http_post(@host, '/heatingCircuits/hc1/temperatureLevels/eco', reset_base64)

      # Reread value and check that it is now back to original value.
      reset_base64 = Km200.http_get(@host, '/heatingCircuits/hc1/temperatureLevels/eco')
      reset_json = @crypto.decrypt(reset_base64)
      reset_value = JSON.parse(reset_json)['value']
      assert_equal(original_value, reset_value)
    end 
  end
end
