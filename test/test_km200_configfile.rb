# Load code to test.
require_relative '../lib/km200_configfile.rb'

# Load other test module for access to example password constants.
# Also loads test/unit.
require_relative './test_km200_crypto.rb'

# Test module for communication with the KM200.
class TestKm200Configfile < Test::Unit::TestCase

  def test_load_configfile
    # First, create a configfile for the test.
    filename = "Example_config_file_used_only_for_tests.yaml"
    File.open(filename, "w") do |f|
      f.puts("gateway_password: #{TestKm200Crypto::Example_gateway_password}")
      f.puts("private_password: #{TestKm200Crypto::Example_private_password}")
      f.puts("host: localhost")
    end
    # Test that configuration settings are loaded correctly from file.
    expected_config = {
      "gateway_password" => TestKm200Crypto::Example_gateway_password,
      "private_password" => TestKm200Crypto::Example_private_password,
      "host" => "localhost"
    }
    actual_config = Km200::
      load_configfile(filename)
    # Remove the test configfile
    File.delete(filename)
    assert_equal(expected_config, actual_config)
  end

  def test_default_configfile
    # function default_configfilename does not replace a non-nil filename
    filename = 'Example_file_which_does_not_exist.yaml'
    assert_raises(Errno::ENOENT){Km200::default_configfilename(filename)}
    filename = 'Example_config_file_used_only_for_tests.yaml'
    # Create empty file
    File.open(filename, "w"){}
    assert_equal(filename, Km200::default_configfilename(filename))
    # Modify home and etc configfile defaults for this test
    home_backup = Km200::Config_Filename_Home.dup
    etc_backup = Km200::Config_Filename_Etc.dup
    # First modify so that no file is found
    Km200::Config_Filename_Home.replace("")
    Km200::Config_Filename_Etc.replace("")
    assert_raises(Errno::ENOENT){Km200::default_configfilename()}
    # except when filename of existing file is given
    assert_equal(filename, Km200::default_configfilename(filename))
    # Next modify so that the home file is found
    Km200::Config_Filename_Home.replace(filename.dup)
    assert_equal(filename, Km200::default_configfilename())
    Km200::Config_Filename_Home.replace("")
    # Next modify so that the etc file is found
    Km200::Config_Filename_Etc.replace(filename.dup)
    assert_equal(filename, Km200::default_configfilename())
    
    # Restore home and etc config file defaults and delete test file
    Km200::Config_Filename_Home.replace(home_backup)
    Km200::Config_Filename_Etc.replace(etc_backup)
    File.delete(filename)
  end

end
