defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "parses -07 request" do
    payload = "test/fixtures/-07-request.bin"
	  |> File.read!()
	message = Roughtime.Wire.parse_packet(payload)
    assert byte_size(message) == 1024
  end

end
