defmodule Roughtime.ServerTest do
  use ExUnit.Case
  doctest Roughtime.Server

  setup do
    {:ok, server} = Roughtime.Server.start_link(%{})
    {:ok, box} = Roughtime.CertBox.start_link(%{})

    %{server: server, box: box}
  end

  @moduletag :capture_log
  test "handles requests" do
    {req, nonc} = Roughtime.Client.generate_request()
    assert nonc != false

    res = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    for {tag, _value} <- got do
      if not Enum.member?([:NONC, :CERT, :INDX, :PATH, :SREP, :SIG], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end
end
