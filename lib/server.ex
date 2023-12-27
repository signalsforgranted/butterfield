defmodule Roughtime.Server do
  use Agent

  @moduledoc """
  Roughtime server logic - sans networking.
  """

  @spec start_link(any()) :: Agent.on_start()
  def start_link(_opts) do
    # Setup Merkle Tree - we stick in random bytes into the root to start with
    # because you can't really start empty, and because I *think* it may
    # mitigate issues down the line. This may be wrong.
    mt =
      MerkleTree.new([:crypto.strong_rand_bytes(32)],
        hash_function: &Roughtime.MerkleCrypto.hash/1
      )

    Agent.start_link(fn -> %{tree: mt} end, name: __MODULE__)
  end

  @spec handle_request(binary()) :: binary()
  def handle_request(request) do
    # TODO: Check length - must be at least 1024 bytes in length
    # Parse incoming request
    req = Roughtime.Wire.parse(request)

    res = %{
      # Generate response with the required tags:
      # CERT
      CERT: Roughtime.CertBox.cert(),

      # VER
      # TODO: Actual version negotiation
      VER: Map.get(req, :VER),

      # NONC
      # TODO: What if NONC is missing?!
      NONC: Map.get(req, :NONC)

      # Merkle Tree
      # INDX
      # PATH

      # TODO: DTAI, DUT1, LEAP Support? Need to look at existing BEAM docs
    }

    srep = %{
      ## ROOT
      ROOT: Map.fetch!(Agent.get(__MODULE__, & &1), :tree).root.value,
      ## MIDP
      MIDP: DateTime.now!("Etc/UTC"),
      ## RADI - As of -08, this is now whole seconds
      RADI: <<1>>
    }

    # SIG
    srep_gen = Roughtime.Wire.generate_message(srep)
    srep_sig = Roughtime.CertBox.sign(srep_gen)

    res = Map.merge(res, %{SREP: srep, SIG: srep_sig})

    Roughtime.Wire.generate(res)
  end
end
