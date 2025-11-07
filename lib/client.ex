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
      # 944 bytes of padding as it should get us to the required amount of
      # padding with the rest of the data structure included to make 1024 bytes
      PAD: :erlang.list_to_binary(List.duplicate(0, 944)),
      TYPE: <<0>>,
      NONC: :crypto.strong_rand_bytes(32),
      VER: Roughtime.Wire.version()
    }

    payload = Roughtime.Wire.generate(req)
    {payload, Map.fetch!(req, :NONC)}
  end
end
