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
      if not Enum.member?([:SIG, :NONC, :TYPE, :PATH, :SREP, :CERT, :INDX], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  @moduletag :capture_log
  test "insertion into merkle tree can be correctly proven" do
    {req, _nonc} = Roughtime.Client.generate_request()
    res = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    # I'm not proud of this.
    assert Map.get(Map.get(got, :SREP), :ROOT) == Roughtime.MerkleCrypto.hash(<<0>> <> req)
  end

  @moduletag :capture_log
  test "srep signature matches" do
    {req, _nonc} = Roughtime.Client.generate_request()
    res = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    raw_srep = Roughtime.Wire.generate_message(Map.get(got, :SREP))
    assert res =~ raw_srep

    got_sig = Roughtime.CertBox.sign(raw_srep)
    assert Map.get(got, :SIG) == got_sig

    assert :public_key.verify(
             Roughtime.CertBox.response_context() <> raw_srep,
             :ignored,
             Map.get(got, :SIG),
             {:ed_pub, :ed25519, get_in(got, [:CERT, :DELE, :PUBK])}
           )
  end
end
