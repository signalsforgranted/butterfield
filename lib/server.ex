require Logger

defmodule Roughtime.Server do
  use Agent

  @moduledoc """
  Roughtime server logic without network interactions.

  "Quid celerius tempore?"
  """

  # Which version we support - this is draft-ietf-ntp-roughtime-14
  @supported_version <<14, 0, 0, 128>>

  # Default value for RADI until we know better precision
  # As of -11, this must be at least 3 seconds
  @default_precision <<3, 0, 0, 0>>

  @spec start_link(any()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec handle_request(binary()) :: binary()
  def handle_request(request) do
    # TODO: Check length - must be at least 1024 bytes in length

    # Parse incoming request
    req = Roughtime.Wire.parse(request)
    Logger.debug("Received request: #{inspect(req)}")

    # TODO: Check the :TYPE tag
    res_ver = check_version(Map.get(req, :VER))

    mt =
      MerkleTree.new([Map.get(req, :NONC)],
        hash_function: &Roughtime.MerkleCrypto.hash/1
      )

    srep = %{
      VER: res_ver,
      RADI: @default_precision,
      MIDP: DateTime.now!("Etc/UTC"),
      VERS: @supported_version,
      ROOT: mt.root.value
    }

    srep_msg = Roughtime.Wire.generate_message(srep)
    srep_sig = Roughtime.CertBox.sign(srep_msg)

    res = %{
      SIG: srep_sig,
      NONC: Map.get(req, :NONC),
      TYPE: <<1>>,
      PATH: <<"">>,
      SREP: srep_msg,
      CERT: Roughtime.CertBox.cert(),
      INDX: <<0, 0, 0, 0>>
    }

    Roughtime.Wire.generate(res)
  end

  defp check_version(vers) do
    vers = for <<version::size(4)-binary <- vers>>, do: version
    Enum.find(vers, &(&1 == @supported_version))
  end
end
