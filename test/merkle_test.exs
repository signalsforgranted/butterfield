defmodule Roughtime.MerkleCryptoTest do
  use ExUnit.Case

  test "Hashes correctly" do
    expected = :crypto.hash(:sha512, "roughtime")
    got = Roughtime.MerkleCrypto.hash("roughtime")
    assert got == expected
  end
end
