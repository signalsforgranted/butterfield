require Logger

defmodule Roughtime.Server do
  use Agent

  @moduledoc """
  Roughtime server logic without network interactions.

  "Quid celerius tempore?"
  """

  # Which version we support - this is draft-ietf-ntp-roughtime-14
  @supported_version <<12, 0, 0, 128>>

  # Default value for RADI until we know better precision
  # As of -11, this must be at least 3 seconds
  @default_precision <<3, 0, 0, 0>>

  # Request payloads should be at least this big to mitigate DDoS amplification
  # types of attacks with the protocol.
  @min_request_size 1024

  @spec start_link(any()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec handle_request(binary()) :: binary()
  def handle_request(request)
      when is_binary(request) and byte_size(request) >= @min_request_size do
    # Parse incoming request
    req = Roughtime.Wire.parse(request)

    # Get the version
    res_ver = check_version(Map.get(req, :VER))

    # TODO: Check SRV tag, we don't support multiple long-term keys.
    # TODO: Check the :TYPE tag
    # TODO: Logic if we don't match the version?

    # We're okay? Let's send a response
    generate_response(req, request, res_ver)
  end

  @spec generate_response(binary(), any(), binary()) :: binary()
  defp generate_response(req, request, ver) do
    [root, index, path] = Roughtime.MerkleTree.update_tree(request)

    srep = %{
      VER: ver,
      RADI: @default_precision,
      MIDP: DateTime.now!("Etc/UTC"),
      VERS: @supported_version,
      ROOT: root
    }

    srep_msg = Roughtime.Wire.generate_message(srep)
    srep_sig = Roughtime.CertBox.sign(srep_msg)

    res = %{
      SIG: srep_sig,
      NONC: Map.get(req, :NONC),
      TYPE: Roughtime.Wire.response_type(),
      PATH: path,
      SREP: srep_msg,
      CERT: Roughtime.CertBox.cert(),
      INDX: index
    }

    Roughtime.Wire.generate(res)
  end

  defp check_version(vers) do
    vers = for <<version::size(4)-binary <- vers>>, do: version
    Enum.find(vers, &(&1 == @supported_version))
  end
end
