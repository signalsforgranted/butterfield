defmodule Roughtime.Client do
  @moduledoc """
  Roughtime client. We keep the network handling out of this module, same with
  any wire serialisation.
  """

  @doc """
  Generate a request packet.
  Returns a tuple containing the serialised packet, and the nonce - the latter
  will be needed in order to validate the response from the server.
  """
  @spec generate_request(atom()) :: {binary(), binary()}
  def generate_request(protocol \\ :ietf) do
    req = %{
      # 944 bytes of padding as it should get us to the required amount of
      # padding with the rest of the data structure included to make 1024 bytes
      PAD: :erlang.list_to_binary(List.duplicate(0, 944)),
      NONC: :crypto.strong_rand_bytes(32)
    }

    req =
      if protocol == :ietf do
        Map.put(req, :VER, Roughtime.Wire.version())
      else
        req
      end

    payload = Roughtime.Wire.generate(req, protocol)
    {payload, Map.fetch!(req, :NONC)}
  end
end
