defmodule Roughtime.ClientTest do
  use ExUnit.Case
  doctest Roughtime.Client

  test "generates an IETF request" do
    {req, nonc} = Roughtime.Client.generate_request()
    assert nonc != nil
    parsed = Roughtime.Wire.parse(req)
    assert Map.fetch!(parsed, :NONC) == nonc
  end
end
