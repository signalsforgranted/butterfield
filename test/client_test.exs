defmodule Roughtime.ClientTest do
  use ExUnit.Case
  doctest Roughtime.Client

  test "generates a classic request" do
    {req, nonc} = Roughtime.Client.generate_request(:classic)
    assert nonc != nil
    parsed = Roughtime.Wire.parse_message(req)
    assert Map.fetch!(parsed, :NONC) == nonc
  end

  test "generates an IETF request" do
    {req, nonc} = Roughtime.Client.generate_request()
    assert nonc != nil
    parsed = Roughtime.Wire.parse(req)
    assert Map.fetch!(parsed, :NONC) == nonc
  end
end
