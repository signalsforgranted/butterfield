defmodule Roughtime.CertBoxTest do
  use ExUnit.Case, async: true
  doctest Roughtime.CertBox

  setup do
    {pubkey, prikey} = :crypto.generate_key(:eddsa, :ed25519)

    {:ok, box} =
      Roughtime.CertBox.start_link(%{
        lt_prikey: Base.encode64(prikey),
        lt_pubkey: Base.encode64(pubkey),
        cert_duration: 2
      })

    %{box: box, lt_prikey: prikey, lt_pubkey: pubkey}
  end

  @moduletag :capture_log
  test "generates temporary long-term key" do
    pubkey = Roughtime.CertBox.pubkey()
    assert pubkey != nil
  end

  @moduletag :capture_log
  test "generates hash of long-term public key" do
    pubkey_hash = Roughtime.CertBox.lt_pubkey_hash()
    assert byte_size(pubkey_hash) == 32
  end

  @moduletag :capture_log
  test "generates new keys and valid certificate with signature", context do
    cert = Roughtime.CertBox.cert()
    assert cert != nil

    pubkey = Roughtime.CertBox.pubkey()
    assert byte_size(pubkey) == 32

    cert = Roughtime.Wire.parse_message(cert, false)

    assert :public_key.verify(
             Roughtime.CertBox.delegation_context() <> Map.fetch!(cert, :DELE),
             :ignored,
             Map.fetch!(cert, :SIG),
             {:ed_pub, :ed25519, Map.fetch!(context, :lt_pubkey)}
           )
  end

  @moduletag :capture_log
  test "can sign a response with temporary keys", _context do
    pubkey = Roughtime.CertBox.pubkey()
    payload = <<"test string">>
    sig = Roughtime.CertBox.sign(payload)

    assert :public_key.verify(
             Roughtime.CertBox.response_context() <> payload,
             :ignored,
             sig,
             {:ed_pub, :ed25519, pubkey}
           )
  end
end
