defmodule Roughtime.CertBoxTest do
  use ExUnit.Case, async: true
  doctest Roughtime.CertBox

  setup do
    {:ok, box} = Roughtime.CertBox.start_link(%{})
    %{box: box}
  end

  @moduletag :capture_log
  test "generates temporary long-term key" do
    Roughtime.CertBox.generate()
    pubkey = Roughtime.CertBox.pubkey()
    assert pubkey != nil
  end

  @moduletag :capture_log
  test "generates new keys and valid certificate with signature" do
    {test_pubkey, test_prikey} = :libdecaf_curve25519.eddsa_keypair()
    Roughtime.CertBox.generate(test_prikey)
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
             test_pubkey,
             Roughtime.CertBox.delegation_context()
           )
  end

  @moduletag :capture_log
  test "can sign a response with temporary keys" do
    Roughtime.CertBox.generate()
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
