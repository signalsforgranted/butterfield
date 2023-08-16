defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "parses -07 request" do
    payload = "test/fixtures/-07-request.bin"
	  |> File.read!()
	request = Roughtime.Wire.parse_packet(payload)
  end

end
