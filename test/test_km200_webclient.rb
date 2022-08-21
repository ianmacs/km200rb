# Package for unit tests
require 'test/unit'

class TestKm200Webclient < Test::Unit::TestCase
  def test_http_get
    # Test that http_get returns the expected response body.
    assert_equal("Hello World", Km200::http_get("localhost", "/"))
  end
end
