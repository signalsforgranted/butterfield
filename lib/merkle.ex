defmodule Roughtime.MerkleTree do
  @moduledoc """
  Builds a Merkle tree over a batch of requests.
  """

  @doc """
  Build a tree over a batch of request packets. Returns the root, and a path for
  each request, in the same order, ready to use as its PATH tag.
  """
  @spec build([binary(), ...]) :: {binary(), [binary()]}
  def build(requests) do
    tree = MerkleTree.build(requests, hash_function: &Roughtime.MerkleCrypto.hash/1)

    # The library lists siblings from the root down; PATH goes from the leaf up.
    paths =
      for {_request, index} <- Enum.with_index(requests) do
        tree |> MerkleTree.Proof.prove(index) |> Enum.reverse() |> Enum.join()
      end

    {tree.value, paths}
  end
end
