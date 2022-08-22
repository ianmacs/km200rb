# Package for unit tests
require 'test/unit'

# We'll do some http get and post testing and need a web server for those
require 'webrick'

# Load code to test
require_relative '../lib/km200_crypto.rb'

# Test module of crypto functions for the KM200
class TestKm200Crypto < Test::Unit::TestCase
  Example_gateway_password = "NeUCsyQMLVYqKJec".b
  Example_private_password = "HnE75f+a%aXP".b
  Example_key =
    "\x91\xdf\x2c\xd7\x63\x1c\x30\x9f\x20\x27\xb8\x9a\x51\x26\xa4\x81".b +
    "\xbf\x39\xad\xe2\x56\x5b\x0a\xf0\x94\x7f\xaa\xd4\x56\xa5\xcc\x9c".b

  # Test that magic array for key generation is correct
  def test_magic
    # A sequence of 32 magic bytes used by Buderus to generate the AES key
    expected_magic = [0x86, 0x78, 0x45, 0xe9, 0x7c, 0x4e, 0x29, 0xdc, 0xe5,
      0x22, 0xb9, 0xa7, 0xd3, 0xa3, 0xe0, 0x7b, 0x15, 0x2b, 0xff, 0xad, 0xdd,
      0xbe, 0xd7, 0xf5, 0xff, 0xd8, 0x42, 0xe9, 0x89, 0x5a, 0xd1, 0xe4];
    actual_magic = Km200::Magic.bytes
    assert_equal(expected_magic, actual_magic)
  end

  def test_md5sum
    # Test that md5sum is correct: empty string
    expected_md5sum =
      "\xd4\x1d\x8c\xd9\x8f\x00\xb2\x04\xe9\x80\x09\x98\xec\xf8\x42\x7e".b
    actual_md5sum = Km200::md5sum("".b)
    assert_equal(expected_md5sum, actual_md5sum)

    # Test case from documentation: First half of example key
    expected_md5sum = Example_key[0..15]
    actual_md5sum = Km200::md5sum(Example_gateway_password + Km200::Magic)
    assert_equal(expected_md5sum, actual_md5sum)
  end

  def test_key_part1_generation
    expected_key_part1 = Example_key[0..15]
    actual_key_part1 = Km200::key_part1(Example_gateway_password)
    assert_equal(expected_key_part1, actual_key_part1)
  end

  def test_key_part2_generation
    expected_key_part2 = Example_key[16..31]
    actual_key_part2 = Km200::key_part2(Example_private_password)
    assert_equal(expected_key_part2, actual_key_part2)
  end

  def test_key_generation
    actual_key = Km200::key(Example_gateway_password, Example_private_password)
    assert_equal(Example_key, actual_key)
  end

  def test_base64_encode
    # Test that base64 encoding is correct: empty string
    expected_base64_encoded = ""
    actual_base64_encoded = Km200::base64_encode("".b)
    assert_equal(expected_base64_encoded, actual_base64_encoded)

    # Some non-empty binary data
    expected_base64_encoded = "aGVsbG8gd29ybGQ="
    actual_base64_encoded = Km200::base64_encode("hello world".b)
    assert_equal(expected_base64_encoded, actual_base64_encoded.strip)

    # Test base64 encoding of string with more than 64 bytes
    teststring= "\x01ABC".b*17
    expected_base64_encoded =
      "AUFCQwFBQkMBQUJDAUFCQwFBQkMBQUJDAUFCQwFBQkMBQUJDAUFCQwFBQkMBQUJDAUFCQwFBQkMB\n" +
      "QUJDAUFCQwFBQkM="
    actual_base64_encoded = Km200::base64_encode(teststring)
    assert_equal(expected_base64_encoded.delete("\n"),
                 actual_base64_encoded.delete("\n"))
  end

  def test_base64_decode
    # Test that base64 decoding is correct: empty string
    expected_base64_decoded = ""
    actual_base64_decoded = Km200::base64_decode("".b)
    assert_equal(expected_base64_decoded, actual_base64_decoded)

    # Some non-empty binary data
    expected_base64_decoded = "\xA1ABC".b*17
    test_data = 
      "oUFCQ6FBQkOhQUJDoUFCQ6FBQkOhQUJDoUFCQ6FBQkOhQUJDoUFCQ6FBQkOhQUJDoUFCQ6FBQkOh\n" +
      "QUJDoUFCQ6FBQkM="
    actual_base64_decoded = Km200::base64_decode(test_data)
    assert_equal(expected_base64_decoded, actual_base64_decoded)
  end

  def test_encrypt
    # Test that AES encryption of '{"value":    55}' is correct
    expected_aes_encrypted_base64 = "CrzAyGdGDqmdxVWZrIXvCg==\n"
    actual_aes_encrypted_base64 =
      Km200::aes_encrypt_base64('{"value":    55}', Example_key)
    assert_equal(expected_aes_encrypted_base64, actual_aes_encrypted_base64)

    # Test padding
    expected_aes_encrypted_base64 = "D+YsDffkGOj5CCK487Cpkg==\n"
    actual_aes_encrypted_base64 =
      Km200::aes_encrypt_base64("{\"value\":55}\0\0\0\0", Example_key)
    assert_equal(expected_aes_encrypted_base64, actual_aes_encrypted_base64)
    actual_aes_encrypted_base64 =
      Km200::aes_encrypt_base64("{\"value\":55}", Example_key)
    assert_equal(expected_aes_encrypted_base64, actual_aes_encrypted_base64)
  end

  def test_decrypt
    # Test that AES decryption of 'CrzAyGdGDqmdxVWZrIXvCg==' is correct
    expected_aes_decrypted = '{"value":    55}'
    actual_aes_decrypted =
      Km200::aes_decrypt_base64('CrzAyGdGDqmdxVWZrIXvCg==', Example_key)
    assert_equal(expected_aes_decrypted, actual_aes_decrypted)

    # Test padding removal
    expected_aes_decrypted = "{\"value\":55}"
    actual_aes_decrypted =
      Km200::aes_decrypt_base64("D+YsDffkGOj5CCK487Cpkg==", Example_key)
    assert_equal(expected_aes_decrypted, actual_aes_decrypted)
  end

  def test_Crypto_class
    filename = "Example_credentials_file_used_only_for_tests.yaml"
    # Test the class which reads credentials from file and stores the key.
    File.open(filename, "w"){|f|
      f.puts("gateway_password: #{Example_gateway_password}")
      f.puts("private_password: #{Example_private_password}")
      f.puts("host: required_but_unused_field")
    }
    crypto = Km200::Crypto.new(filename)
    ciphertext = "D+YsDffkGOj5CCK487Cpkg==\n"
    cleartext = '{"value":55}'
    actual_encrypted = crypto.encrypt(cleartext)
    assert_equal(ciphertext, actual_encrypted)
    actual_decrypted = crypto.decrypt(ciphertext)
    assert_equal(cleartext, actual_decrypted)

    # Test round-trip encryption and decryption for longer string
    cleartext = "This is a longer string which should be encrypted and decrypted correctly."
    actual_encrypted = crypto.encrypt(cleartext)
    actual_decrypted = crypto.decrypt(actual_encrypted)
    assert_equal(cleartext, actual_decrypted)

    File.delete(filename)
  end
end
