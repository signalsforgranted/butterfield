defmodule Roughtime.ServerTest do
  use ExUnit.Case
  doctest Roughtime.Server

  @moduletag :capture_log

  setup do
    {:ok, server} = Roughtime.Batcher.start_link(%{})
    {:ok, box} = Roughtime.CertBox.start_link(%{})

    %{server: server, box: box}
  end

  # Create the boilerplate for requests, allowing changes to replace/add values
  defp request(changes) do
    %{
      ZZZZ: :binary.copy(<<0>>, 944),
      VER: Roughtime.Wire.version(),
      TYPE: Roughtime.Wire.request_type(),
      NONC: :crypto.strong_rand_bytes(32)
    }
    |> Map.merge(changes)
    |> Map.reject(fn {_tag, value} -> is_nil(value) end)
    |> Roughtime.Wire.generate()
  end

  defp handle(changes), do: Roughtime.Server.handle_request(request(changes))

  test "ignores unknown tags" do
    assert {:ok, _} = handle(%{TEST: "test"})
  end

  describe "VER" do
    test "accepts version 1 anywhere in the list" do
      assert {:ok, _} = handle(%{VER: <<2, 0, 0, 0, 1, 0, 0, 0>>})
    end

    test "ignores requests without version 1" do
      error = {:error, "No supported version in VER"}
      assert handle(%{VER: <<2, 0, 0, 0, 3, 0, 0, 0>>}) == error
      assert handle(%{VER: <<1, 0, 0>>}) == error
      assert handle(%{VER: nil}) == error
    end
  end

  describe "TYPE" do
    test "ignores anything but a request" do
      error = {:error, "TYPE missing or not a request"}
      assert handle(%{TYPE: Roughtime.Wire.response_type()}) == error
      assert handle(%{TYPE: <<180>>}) == error
      assert handle(%{TYPE: nil}) == error
    end
  end

  describe "SRV" do
    test "accepts our long-term key, or none" do
      assert {:ok, _} = handle(%{SRV: Roughtime.CertBox.lt_pubkey_hash()})
      assert {:ok, _} = handle(%{})
    end

    test "ignores another server's key" do
      other = Roughtime.CertBox.srv_hash(:crypto.strong_rand_bytes(32))
      assert handle(%{SRV: other}) == {:error, "SRV does not match the long-term key"}
    end
  end

  describe "NONC" do
    test "ignores a missing or wrong-sized nonce" do
      error = {:error, "NONC missing or not 32 bytes"}
      assert handle(%{NONC: :crypto.strong_rand_bytes(16)}) == error
      assert handle(%{NONC: :crypto.strong_rand_bytes(64)}) == error
      assert handle(%{NONC: nil}) == error
    end
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

    assert :crypto.verify(
             :eddsa,
             :none,
             Roughtime.CertBox.response_context() <> raw_srep,
             Map.get(got, :SIG),
             [get_in(got, [:CERT, :DELE, :PUBK]), :ed25519]
           )
  end
end
