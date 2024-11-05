defmodule Roughtime.Server do
  use Agent

  @moduledoc """
  Roughtime server logic without network interactions.

  "Quid celerius tempore?"
  """

  # Which version we support - this is draft-ietf-ntp-roughtime-11
  @supported_version <<11, 0, 0, 128>>

  # Default value for RADI until we know better precision
  # As of -11, this must be at least 3 seconds
  @default_precision <<3, 0, 0, 0>>

  @spec start_link(any()) :: Agent.on_start()
  def start_link(_opts) do
    mt =
      MerkleTree.new([],
        hash_function: &Roughtime.MerkleCrypto.hash/1
      )

    Agent.start_link(fn -> %{tree: mt} end, name: __MODULE__)
  end

  @spec handle_request(binary()) :: binary()
  def handle_request(request) do
    # TODO: Check length - must be at least 1024 bytes in length

    # Parse incoming request
    req = Roughtime.Wire.parse(request)

    res_ver = check_version(Map.get(req, :VER))

    res = %{
      CERT: Roughtime.CertBox.cert(),
      VER: res_ver,

      # TODO: What if NONC is missing?!
      NONC: Map.get(req, :NONC),

      # Merkle Tree
      # TODO: Add these actual values, rather than lying here
      INDX: <<0, 0, 0, 0>>,
      PATH: <<"">>
    }

    srep = %{
      ROOT: Map.fetch!(Agent.get(__MODULE__, & &1), :tree).root.value,
      MIDP: DateTime.now!("Etc/UTC"),
      # RADI - As of -08, this is now whole seconds
      RADI: @default_precision
    }

    # Sign SREP
    srep_gen = Roughtime.Wire.generate_message(srep)
    srep_sig = Roughtime.CertBox.sign(srep_gen)

    res = Map.merge(res, %{SREP: srep, SIG: srep_sig})

    Roughtime.Wire.generate(res)
  end

  defp check_version(vers) do
    vers = for <<version::size(4)-binary <- vers>>, do: version
    Enum.find(vers, &(&1 == @supported_version))
  end
end
