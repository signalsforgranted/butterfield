defmodule Roughtime.CertTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, box} = Roughtime.CertBox.start_link(%{})
    %{box: box}
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
end
