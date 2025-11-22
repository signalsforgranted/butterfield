defmodule Roughtime.MerkleTreeTest do
  use ExUnit.Case, async: true
  doctest Roughtime.MerkleTree

  setup do
    {:ok, tree} = Roughtime.MerkleTree.start_link(%{})
    %{box: tree}
  end

  @moduletag :capture_log
  test "inserts into tree and calculates values" do
    [root, _idx, _path] = Roughtime.MerkleTree.update_tree(:crypto.strong_rand_bytes(128))
    assert root != nil
  end
end
