# File contains the crypto-related functions for talking to the KM200 device.
# They are implemented as module-functions of Ruby module Km200.
# 
# When reading data from the Web-KM200 via HTTP GET, or when modifying data
# via HTTP POST, the HTTP body contains base-64 encoded data that was encrypted
# using a 'secret' key.
#
# The purpose of the encryption is _not_ to prevent unauthorized access to the
# Web-KM200, but to obfuscate the communication with the device so that normal
# Customers prefer to use the manufacturer's smartphone app instead of trying to
# communicate the Web-KM200 on their own.
#
# E.g. it is possible to simply replay previously recorded commands to the
# Web-KM200, because the same cleartext always maps to the same ciphertext and
# vice versa, and the communication with the Web-KM200 does not use SSL. In the
# same way, read commands that read sensor data, e.g.,  can be catalogued and
# then the catalogue can be used to map different ciphertexts to the cleartext
# sensor data without knowing the secret key or even the encryption method used.
# (This may be an opportunity for microcontroller-based solutions that cannot
# afford to include a full-fledged crypto library.)
#
# The encryption is implemented using AES-256 in CBC mode.  The key is derived
# from the gateway password (printed on a sticker on the Web-KM200), a series of
# 32 "magic" bytes, and the private password (set by the customer when
# initializing their Web-KM200 using the smartphone app).
# 
# This file includes functions to derive the key from gateway and private
# password and for encrypting and decrypting data sent to or received from the
# Web-KM200.

require 'digest/md5'
require 'base64'
require 'openssl'
require 'yaml'
require_relative 'km200_configfile'

# Namespace for Buderus Web-KM200 related stuff
module Km200
  # Sequence of magic bytes needed for key generation
  Magic = ("\x86\x78\x45\xe9\x7c\x4e\x29\xdc\xe5\x22\xb9\xa7\xd3\xa3\xe0\x7b" +
           "\x15\x2b\xff\xad\xdd\xbe\xd7\xf5\xff\xd8\x42\xe9\x89\x5a\xd1\xe4").b
  
  # Calculate md5sum of a string, return a string of bytes
  def self.md5sum(string)
    Digest::MD5.digest(string)
  end

  # Calculate key part 1 from gateway password, return a string of bytes
  def self.key_part1(gateway_password)
    md5sum(gateway_password + Magic)
  end

  # Calculate key part 2 from private password, return a string of bytes
  def self.key_part2(private_password)
    md5sum(Magic + private_password)
  end

  # Calculate key from gateway password and private password, return a string of bytes
  def self.key(gateway_password, private_password)
    key_part1(gateway_password) + key_part2(private_password)
  end

  # Encode binary string as base64, return ASCII string
  def self.base64_encode(string)
    Base64.encode64(string)
  end

  # Decode base64 string, return binary string
  def self.base64_decode(string)
    Base64.decode64(string)
  end

  # Encrypt data with key and encode as base64, return ASCII string.
  # data will be padded with zeros to a multiple of 16 bytes at the end.
  def self.aes_encrypt_base64(data, key)
    padding = (-data.bytesize) % 16
    data += "\0" * padding
    aes = OpenSSL::Cipher::AES.new(256, :ECB)
    aes.encrypt
    aes.key = key
    aes.padding = 0
    base64_encode(aes.update(data) + aes.final)
  end

  # Decrypt base64 encoded data with key, return cleartext but remove any 0 bytes
  def self.aes_decrypt_base64(data, key)
    aes = OpenSSL::Cipher::AES.new(256, :CBC)
    aes.decrypt
    aes.key = key
    aes.padding = 0
    (aes.update(base64_decode(data)) + aes.final).delete("\0")
  end

  # Class for handling the crypto (stores key)
  class Crypto
    # Create new Crypto object from credentials stored in given file.
    # If no file is given, the default credentials file are tried:
    # ~/.km200_credentials.yml and /etc/km200_credentials.yml
    # If no credentials file is found or the credentials file does not
    # contain the gateway_password or private_password, an exception is raised.
    # The credentials YAML file must contain the following fields:
    #
    # gateway_password: string # password from sticker on Web-KM200
    # private_password: string # password set by customer in smartphone app
    def initialize(filename = nil)
      credentials = Km200::load_configfile(filename)
      @key = Km200::key(credentials['gateway_password'], credentials['private_password'])
    end
    # Encrypt data with key, return base64 encoded string
    def encrypt(data)
      Km200::aes_encrypt_base64(data, @key)
    end
    # Decrypt base64 encoded cipertext with key, return cleartext
    def decrypt(data)
      Km200::aes_decrypt_base64(data, @key)
    end
  end
end
