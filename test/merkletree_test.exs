defmodule Roughtime.MerkleTreeTest do
  use ExUnit.Case, async: true
  doctest Roughtime.MerkleTree

  defp indx(index), do: <<index::unsigned-little-integer-size(32)>>

  for size <- [1, 2, 3, 5, 8, 64] do
    test "every path in a batch of #{size} proves its request" do
      requests = for _ <- 1..unquote(size), do: :crypto.strong_rand_bytes(1024)
      {root, paths} = Roughtime.MerkleTree.build(requests)

      for {{request, path}, index} <- Enum.with_index(Enum.zip(requests, paths)) do
        assert Roughtime.Client.verify_path(request, indx(index), path, root)
      end
    end
  end

  test "paths grow by one node each time the batch doubles" do
    depths =
      for size <- [1, 2, 3, 4, 5, 64, 65] do
        {_root, [path | _]} = Roughtime.MerkleTree.build(List.duplicate("request", size))
        div(byte_size(path), 32)
      end

    assert depths == [0, 1, 2, 2, 3, 6, 7]
  end

  test "a path proves nothing else" do
    {root, [path | _]} = Roughtime.MerkleTree.build(["a", "b", "c", "d"])

    assert Roughtime.Client.verify_path("a", indx(0), path, root)
    refute Roughtime.Client.verify_path("b", indx(0), path, root)
    refute Roughtime.Client.verify_path("a", indx(1), path, root)
    refute Roughtime.Client.verify_path("a", indx(4), path, root)
  end
end
