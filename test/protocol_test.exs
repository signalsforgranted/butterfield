defmodule Routime.ProtocolTest do
  use ExUnit.Case

  setup do
    {:ok, box} = Roughtime.CertBox.start_link([])
    %{box: box}
  end

  test "generates a classic request" do
    {req, nonc} = Roughtime.Protocol.generate_request(:classic)
    assert nonc != nil
    parsed = Roughtime.Wire.parse_message(req)
    assert Map.fetch!(parsed, :NONC) == nonc
  end

  test "generates an IETF request" do
    {req, nonc} = Roughtime.Protocol.generate_request()
    assert nonc != nil
    parsed = Roughtime.Wire.parse(req)
    assert Map.fetch!(parsed, :NONC) == nonc
  end
end