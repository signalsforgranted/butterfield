defmodule Roughtime.CertTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, box} = Roughtime.CertBox.start_link([])
    %{box: box}
  end

  test "generates new keys" do
    assert Roughtime.CertBox.public_key() == nil
    Roughtime.CertBox.generate()
    assert Roughtime.CertBox.public_key() != nil
  end

  test "generates a signature" do
    Roughtime.CertBox.generate()
    assert byte_size(Roughtime.CertBox.sign("test")) == 64
  end

  test "updates keys" do
    {pub, pri} = :crypto.generate_key(:eddsa, :ed25519)
    Roughtime.CertBox.update(pub, pri)
    assert byte_size(Roughtime.CertBox.sign("updated")) == 64
  end
end
