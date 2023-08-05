defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "generates valid packet" do
    payload = <<0x74657374>>
    got = Roughtime.Wire.generate_packet(payload)
    assert Roughtime.Wire.parse_packet(got) == payload
  end

  test "generates message block" do
  end
end
