# Package for unit tests
require 'test/unit'
require 'json'
require_relative '../lib/km200_webclient.rb'

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

  def test_class_Webclient_json
    if @crypto && @config && @host # skip tests if no credentials available
      webclient = Km200::Webclient.new(@file)

      # Do basically the same as test_http_post above, but using the Webclient class.
      original_json = webclient.read_json('/heatingCircuits/hc1/temperatureLevels/eco')
      original_value = JSON.parse(original_json)['value']

      new_value = (original_value == 5) ? 0 : 5
      new_json = '{"value":%d}' % new_value
      webclient.write_json('/heatingCircuits/hc1/temperatureLevels/eco', new_json)

      altered_json = webclient.read_json('/heatingCircuits/hc1/temperatureLevels/eco')
      altered_value = JSON.parse(altered_json)['value']
      assert_equal(new_value, altered_value)
      assert_not_equal(original_value, altered_value)

      original_json = '{"value":%.1f}' % original_value
      webclient.write_json('/heatingCircuits/hc1/temperatureLevels/eco', original_json)
    end
  end

  def test_class_Webclient_data
    if @crypto && @config && @host # skip tests if no credentials available
      webclient = Km200::Webclient.new(@file)

      # Read a string value
      expected_hardware = 'iCom_Low_NSC_v1'
      actual_hardware = webclient.read_data('/gateway/versionHardware')
      assert_equal(expected_hardware, actual_hardware)

      # Read a numeric value
      temperature = webclient.read_data('/dhwCircuits/dhw1/actualTemp')
      assert_kind_of(Numeric, temperature)

      # Read a switchProgram value
      heating_program = webclient.read_data('/heatingCircuits/hc1/switchPrograms/A')
      assert_kind_of(Array, heating_program)
      assert_equal(28, heating_program.length)
      heating_program.each do |switchPoint|
        assert_kind_of(Hash, switchPoint)
        assert_equal(['dayOfWeek','setpoint','time'], switchPoint.keys)
        assert_kind_of(Numeric, switchPoint['time'])
        assert_kind_of(String, switchPoint['setpoint'])
        assert_kind_of(String, switchPoint['dayOfWeek'])
      end

      # Read a directory listing
      directory = webclient.read_data('/heatingCircuits/hc1')
      assert_kind_of(Set, directory)
      assert_equal(25, directory.length)
      assert_include(directory, '/heatingCircuits/hc1/currentRoomSetpoint')
    end
  end

end
