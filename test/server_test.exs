defmodule Roughtime.ServerTest do
  use ExUnit.Case
  doctest Roughtime.Server

  @moduletag :capture_log

  setup do
    {:ok, server} = Roughtime.Server.start_link(%{})
    {:ok, box} = Roughtime.CertBox.start_link(%{})

    %{server: server, box: box}
  end

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

  test "ignores requests missing the packet header" do
    {req, _nonc} = Roughtime.Client.generate_request()
    <<_header::binary-size(12), message::binary>> = req

    assert {:error, "Malformed packet"} = Roughtime.Server.handle_request(message)
  end

  test "only answers requests at least as big as the response" do
    req = fn pad ->
      Roughtime.Wire.generate(%{
        ZZZZ: :binary.copy(<<0>>, pad),
        TYPE: Roughtime.Wire.request_type(),
        NONC: :crypto.strong_rand_bytes(32),
        VER: Roughtime.Wire.version()
      })
    end

    big = req.(400)
    assert {:ok, res} = Roughtime.Server.handle_request(big)
    assert byte_size(res) <= byte_size(big)

    assert {:error, _} = Roughtime.Server.handle_request(req.(300))
  end

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

  test "insertion into merkle tree can be correctly proven" do
    {req, _nonc} = Roughtime.Client.generate_request()
    {:ok, res} = Roughtime.Server.handle_request(req)
    got = Roughtime.Wire.parse(res)

    # I'm not proud of this.
    assert Map.get(Map.get(got, :SREP), :ROOT) == Roughtime.MerkleCrypto.hash(<<0>> <> req)
  end

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
