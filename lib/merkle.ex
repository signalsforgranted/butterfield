defmodule Roughtime.MerkleCrypto do
  @moduledoc """
  Provide crypto handler for the merkle tree
  The included handler with the library uses Base16 which we don't need, as well
  as supports several other crypto functions, again, we don't need.
  """

  @spec hash(binary()) :: binary()
  def hash(data) do
    :crypto.hash(:sha512, data)
  end
end