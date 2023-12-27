defmodule Roughtime.ServerTest do
  use ExUnit.Case, async: true
  doctest Roughtime.Server

  setup do
    {:ok, server} = Roughtime.Server.start_link(%{})

    %{server: server}
  end

  test "handles requests" do
    Roughtime.CertBox.generate()
    {req, nonc} = Roughtime.Client.generate_request(:ietf)
    assert nonc != false

    res = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    for {tag, _value} <- got do
      # This list matches what roughenough provides, but does not appear to
      # match what draft -05 or -07 produce.
      if not Enum.member?([:INDX, :CERT, :PATH, :SIG, :SREP, :VER, :NONC], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end
end
