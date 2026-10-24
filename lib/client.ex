defmodule Roughtime.Client do
  @moduledoc """
  Roughtime client. We keep the network handling out of this module, same with
  any wire serialisation.

  "Tempus ad lucem ducit veritatem"
  """

  @doc """
  Generate a request packet.
  Returns a tuple containing the serialised packet, and the nonce - the latter
  will be needed in order to validate the response from the server.
  """
  @spec generate_request() :: {binary(), binary()}
  def generate_request do
    req = %{
      # 952 bytes of padding as it should get us to the required amount of
      # padding with the rest of the data structure included to make 1024 bytes
      # (minus the 12 bytes in the header).
      ZZZZ: :erlang.list_to_binary(List.duplicate(0, 952)),
      TYPE: Roughtime.Wire.request_type(),
      NONC: :crypto.strong_rand_bytes(32),
      VER: Roughtime.Wire.version()
    }

    payload = Roughtime.Wire.generate(req)
    {payload, Map.fetch!(req, :NONC)}
  end

  @doc """
  Check that `path` and `index` (the PATH and INDX tags) prove that `request`
  is in the Merkle tree with `root`.
  """
  @spec verify_path(binary(), binary(), binary(), binary()) :: boolean()
  def verify_path(request, <<index::unsigned-little-integer-size(32)>>, path, root) do
    leaf = Roughtime.MerkleCrypto.hash(<<0>> <> request)
    walk(leaf, index, path) == root
  end

  defp walk(hash, 0, <<>>), do: hash

  defp walk(hash, index, <<node::binary-size(32), rest::binary>>) do
    hash =
      if rem(index, 2) == 0,
        do: Roughtime.MerkleCrypto.hash(<<1>> <> hash <> node),
        else: Roughtime.MerkleCrypto.hash(<<1>> <> node <> hash)

    walk(hash, div(index, 2), rest)
  end

  defp walk(_hash, _index, _path), do: nil
end
