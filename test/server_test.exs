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

    {:ok, res} = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    for {tag, _value} <- got do
      if not Enum.member?([:SIG, :NONC, :TYPE, :PATH, :SREP, :CERT, :INDX], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  @moduletag :capture_log
  test "ignores unsupported versions" do
    # No pad, thus too short
    badver_req =
      Roughtime.Wire.generate(%{
        ZZZZ: :erlang.list_to_binary(List.duplicate(0, 944)),
        TYPE: Roughtime.Wire.request_type(),
        NONC: :crypto.strong_rand_bytes(32),
        VER: <<21, 20, 19, 128>>
      })

    {badver_res, _badver_reason} = Roughtime.Server.handle_request(badver_req)
    assert badver_res != :ok
  end

  @moduletag :capture_log
  test "ignores no/insufficent padding" do
    # No pad, thus too short
    nopad_req =
      Roughtime.Wire.generate(%{
        TYPE: Roughtime.Wire.request_type(),
        NONC: :crypto.strong_rand_bytes(32),
        VER: Roughtime.Wire.version()
      })

    {nopad_res, _nopad_reason} = Roughtime.Server.handle_request(nopad_req)
    assert nopad_res != :ok

    shortpad_req =
      Roughtime.Wire.generate(%{
        ZZZZ: :erlang.list_to_binary(List.duplicate(0, 6)),
        TYPE: Roughtime.Wire.request_type(),
        NONC: :crypto.strong_rand_bytes(32),
        VER: Roughtime.Wire.version()
      })

    {shortpad_res, _shortpad_reason} = Roughtime.Server.handle_request(shortpad_req)
    assert shortpad_res != :ok
  end

  @moduletag :capture_log
  test "ignores invalid types" do
    # Response type in request
    wrongtype_req =
      Roughtime.Wire.generate(%{
        ZZZZ: :erlang.list_to_binary(List.duplicate(0, 944)),
        TYPE: Roughtime.Wire.response_type(),
        NONC: :crypto.strong_rand_bytes(32),
        VER: Roughtime.Wire.version()
      })

    {wrongtype_res, _wrongtype_reason} = Roughtime.Server.handle_request(wrongtype_req)
    assert wrongtype_res == :error

    # Not a real type
    weirdtype_req =
      Roughtime.Wire.generate(%{
        ZZZZ: :erlang.list_to_binary(List.duplicate(0, 944)),
        TYPE: <<180>>,
        NONC: :crypto.strong_rand_bytes(32),
        VER: Roughtime.Wire.version()
      })

    {weirdtype_res, _weirdtype_reason} = Roughtime.Server.handle_request(weirdtype_req)
    assert weirdtype_res != :ok
  end

  @moduletag :capture_log
  test "insertion into merkle tree can be correctly proven" do
    {req, _nonc} = Roughtime.Client.generate_request()
    {:ok, res} = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    # I'm not proud of this.
    assert Map.get(Map.get(got, :SREP), :ROOT) == Roughtime.MerkleCrypto.hash(<<0>> <> req)
  end

  @moduletag :capture_log
  test "srep signature matches" do
    {req, _nonc} = Roughtime.Client.generate_request()
    {:ok, res} = Roughtime.Server.handle_request(req)
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
