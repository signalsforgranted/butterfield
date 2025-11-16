defmodule Roughtime.MerkleTree do
  use Agent

  @moduledoc """
  Handle all Merkle Tree functionality.

  We spin this up as an Agent as updates can't easily happen concurrently.
  """
  def start_link(_opts) do
    # We need to know the max depth/number of requests before starting
    tree = %{
      # TODO Map.get!(opts, :max)
      max: 0,
      batch: 0,
      leaves: [],
      tree: nil
    }

    Agent.start_link(fn -> tree end, name: __MODULE__)
  end

  @doc """
  """
  @spec update_tree(binary()) :: list(binary())
  def update_tree(payload) do
    # As we don't yet supporting batching of requests, yes, we just make a new
    # Merkle Tree on each and every request.
    mt =
      MerkleTree.new([payload],
        hash_function: &Roughtime.MerkleCrypto.hash/1
      )

    # Return ROOT, INDX, PATH
    [mt.root.value, <<0, 0, 0, 0>>, <<"">>]
  end
end
