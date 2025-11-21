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
      when is_binary(request) and byte_size(request) < @min_request_size do
    {:error, "Incoming request too short"}
  end

  @doc """
  Process a roughtime request.

  Returns:
    {:ok, binary()} with encoded payload to return to client or,
    {:error, string()} with a human readable reason why the request failed.
  """
  @spec handle_request(binary()) :: binary()
  def handle_request(request)
      when is_binary(request) and byte_size(request) >= @min_request_size do
    # Parse incoming request
    req = Roughtime.Wire.parse(request)

    # Get the version
    res_ver = check_version(Map.get(req, :VER))

    case res_ver do
      @supported_version -> handle_rev_14(req, request)
      # Do nothing for clients which we don't support, just log
      _ -> {:error, "Received unsupported version #{res_ver}"}
    end
  end

  @spec handle_rev_14(binary(), any()) :: binary()
  defp handle_rev_14(req, request) when is_map_key(req, :TYPE) do
    # TODO: Check SRV tag, we don't support multiple long-term keys.

    case Map.fetch!(req, :TYPE) do
      <<0>> -> generate_response(req, request)
      <<1>> -> {:error, "Received a response TYPE in a request?!"}
      _ -> {:error, "Received an unsupported TYPE"}
    end
  end

  @spec generate_response(binary(), any()) :: binary()
  defp generate_response(req, request) do
    [root, index, path] = Roughtime.MerkleTree.update_tree(request)

    srep = %{
      VER: Roughtime.Wire.version(),
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

    {:ok, Roughtime.Wire.generate(res)}
  end

  defp check_version(vers) do
    vers = for <<version::size(4)-binary <- vers>>, do: version
    Enum.find(vers, &(&1 == @supported_version))
  end
end
