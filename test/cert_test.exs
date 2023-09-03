defmodule Roughtime.CertTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, box} = Roughtime.CertBox.start_link(%{})
    %{box: box}
  end

  @moduletag :capture_log
  test "generates new keys" do
    {_test_pubkey, test_prikey} = :libdecaf_curve25519.eddsa_keypair()
    Roughtime.CertBox.generate(test_prikey)
    cert = Roughtime.CertBox.cert()
    assert cert != nil
    pubkey = Roughtime.CertBox.pubkey()
    assert byte_size(pubkey) == 32
  end

end
