defmodule Roughtime.CertBoxTest do
  use ExUnit.Case, async: true
  doctest Roughtime.CertBox

  setup do
    {pubkey, prikey} = :libdecaf_curve25519.eddsa_keypair()

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
  test "generates new keys and valid certificate with signature", context do
    cert = Roughtime.CertBox.cert()
    assert cert != nil

    pubkey = Roughtime.CertBox.pubkey()
    assert byte_size(pubkey) == 32

    cert =
      Map.fetch!(Roughtime.Wire.parse_message(cert, false), :CERT)
      |> Roughtime.Wire.parse_message(false)

    assert :libdecaf_curve25519.ed25519ctx_verify(
             Map.fetch!(cert, :SIG),
             Map.fetch!(cert, :DELE),
             Map.fetch!(context, :lt_pubkey),
             Roughtime.CertBox.delegation_context()
           )
  end

  # @moduletag :capture_log
  test "can sign a response with temporary keys", _context do
    pubkey = Roughtime.CertBox.pubkey()
    payload = <<"test string">>
    sig = Roughtime.CertBox.sign(payload)

    assert :libdecaf_curve25519.ed25519ctx_verify(
             sig,
             payload,
             pubkey,
             Roughtime.CertBox.response_context()
           )
  end
end
