defmodule Roughtime.Protocol do
  @moduledoc """
  Although the logic of the Roughtime protocol is really simple, this module
  exists to keep protocol logic out of [Roughtime.Wire](`Roughtime.Wire`), and
  also out of any GenServer(s). Here we also avoid any network interactions but
  do depend on [RoughTime.CertBox](`Roughtime.CertBox`) to generate signing of
  responses.
  """

  # Where IETF versions are set (Google implementations don't have this)
  # @supported_versions [<<1,0,0,0>>]

  # RADI is supposed to be the value representing estimated accuracy,
  # however in reality other implementations just hard code this to a fixed
  # number where it's not known.
  # @radi_magic_number 1000000

  @doc """
  Generate a request packet.
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
