defmodule Roughtime.RFCTest do
  use ExUnit.Case, async: true

  setup_all do
    responses =
      "test/fixtures/rfc10049-malfeasance.json"
      |> File.read!()
      |> JSON.decode!()
      |> Map.fetch!("responses")
      |> Enum.map(fn r -> Map.new(r, fn {k, v} -> {k, Base.decode64!(v)} end) end)

    %{responses: responses}
  end

  # Parse without expanding nested tags, so signed values keep their raw bytes.
  defp parse_raw(<<_header::binary-size(12), message::binary>>) do
    Roughtime.Wire.parse_message(message, false)
  end

  defp verify(context, payload, sig, pubkey) do
    :public_key.verify(context <> payload, :ignored, sig, {:ed_pub, :ed25519, pubkey})
  end

  test "parses requests", %{responses: responses} do
    for %{"request" => request} <- responses do
      req = Roughtime.Wire.parse(request)
      assert req[:VER] == Roughtime.Wire.version()
      assert req[:TYPE] == Roughtime.Wire.request_type()
      assert byte_size(req[:NONC]) == 32
    end
  end

  test "parses responses", %{responses: responses} do
    for %{"request" => request, "response" => response} <- responses do
      res = Roughtime.Wire.parse(response)
      assert res[:TYPE] == Roughtime.Wire.response_type()
      assert res[:NONC] == Roughtime.Wire.parse(request)[:NONC]
      assert %{VER: _, RADI: _, MIDP: %DateTime{}, VERS: _, ROOT: _} = res[:SREP]
      assert %{DELE: %{MINT: _, MAXT: _, PUBK: _}, SIG: _} = res[:CERT]
    end
  end

  test "SRV is the hash of the long-term key", %{responses: responses} do
    for %{"publicKey" => pubkey, "request" => request} <- responses do
      assert Roughtime.Wire.parse(request)[:SRV] == Roughtime.CertBox.srv_hash(pubkey)
    end
  end

  test "CERT is signed by the long-term key", %{responses: responses} do
    for %{"publicKey" => pubkey, "response" => response} <- responses do
      cert = Roughtime.Wire.parse_message(parse_raw(response)[:CERT], false)
      assert verify(Roughtime.CertBox.delegation_context(), cert[:DELE], cert[:SIG], pubkey)
    end
  end

  test "SREP is signed by the delegated key", %{responses: responses} do
    for %{"response" => response} <- responses do
      res = parse_raw(response)
      dele = Roughtime.Wire.parse(response)[:CERT][:DELE]
      assert verify(Roughtime.CertBox.response_context(), res[:SREP], res[:SIG], dele[:PUBK])
    end
  end

  test "ROOT is the Merkle root of the request", %{responses: responses} do
    for %{"request" => request, "response" => response} <- responses do
      res = Roughtime.Wire.parse(response)
      assert Roughtime.MerkleTree.build([request]) == {res[:SREP][:ROOT], [res[:PATH]]}
      assert Roughtime.Client.verify_path(request, res[:INDX], res[:PATH], res[:SREP][:ROOT])
    end
  end
end
