require Logger

defmodule Roughtime.CertBox do
  use GenServer

  @moduledoc """
  Handle and generate key material.

  Roughtime has the concept of two sets of key material - the "long term key"
  which is just a public/private keypair which is provided via the Application
  runtime configuration, and a temporary keypair which has some defined time
  range of validity that is generated at service start up. When the service
  initialises, we generate a new temporary keypair and sign it with the
  long-term key. All responses are then signed with the temporary key. A new
  temporary key can be generated at a later time (important for long-running
  instances that exceed the `MAXT` value, but require the long-term private key
  again to do so.
  """

  # Default duration in hours of temporary certificates made off the long-term
  @default_cert_duration 24

  # MINT is backdated so that a MIDP taken just before a rotation is still
  # inside the new certificate
  @backdate_hours 1

  # Context Strings are required when signing messages, earlier versions used
  # "Ed25519ctx" cryptographic functions, however as these are not well
  # supported across libraries and languages, these context strings are now
  # prepended before the payload to be signed.
  #
  # Roughtime responses have two signatures - one for the temporal certificate,
  # which is everything inside `DELE` tag.
  @doc """
  Delegation Context is used when signing the temporary certificate.
  """
  @delegation_context "RoughTime v1 delegation signature" <> <<0>>
  @spec delegation_context() :: String.t()
  def delegation_context do
    @delegation_context
  end

  @doc """
  Response Context is used when signing the `SREP` tag.
  """
  @response_context "RoughTime v1 response signature" <> <<0>>
  @spec response_context() :: String.t()
  def response_context do
    @response_context
  end

  @doc """
  The `SRV` value for a long-term public key.
  """
  @spec srv_hash(binary()) :: binary()
  def srv_hash(lt_pubkey) do
    <<:crypto.hash(:sha512, <<0xFF>> <> lt_pubkey)::binary-size(32)>>
  end

  @doc """
  Start the Agent, and set up pre-signing of the certificate and temporary keys.
  Map should contain the long term private key as `lt_prikey`, and public key as
  `lt_pubkey`. If either aren't set, we just make some temporary ones.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(keys) do
    GenServer.start_link(__MODULE__, keys, name: __MODULE__)
  end

  @impl true
  def init(keys) do
    # We don't have keys, make temp...
    {lt_pubkey, lt_prikey} =
      if Map.get(keys, :lt_prikey) != nil and Map.get(keys, :lt_pubkey) != nil do
        dc_prikey = Base.decode64!(Map.get(keys, :lt_prikey))
        dc_pubkey = Base.decode64!(Map.get(keys, :lt_pubkey))
        {dc_pubkey, dc_prikey}
      else
        Logger.warning("No long-term keys provided, generating some")
        :crypto.generate_key(:eddsa, :ed25519)
      end

    duration = Map.get(keys, :cert_duration, @default_cert_duration)

    state =
      generate(lt_pubkey, lt_prikey, duration)
      |> Map.merge(%{lt_prikey: lt_prikey, duration: duration})

    schedule_rotation(duration)
    {:ok, state}
  end

  @impl true
  def handle_info(:rotate, state) do
    schedule_rotation(state.duration)
    {:noreply, Map.merge(state, generate(state.lt_pubkey, state.lt_prikey, state.duration))}
  end

  @impl true
  def handle_call({:get, key}, _from, state), do: {:reply, Map.fetch!(state, key), state}

  def handle_call(:signing, _from, state), do: {:reply, {state.prikey, state.cert}, state}

  # Keep private keys out of crash reports and :sys.get_status/1
  @impl true
  def format_status(status) do
    Map.replace_lazy(status, :state, &Map.drop(&1, [:lt_prikey, :prikey]))
  end

  defp schedule_rotation(duration) do
    Process.send_after(self(), :rotate, div(:timer.hours(duration), 2))
  end

  @doc """
  Generate the temporary keys and pre-generate the CERT and nested tags
  """
  @spec generate(binary(), binary(), pos_integer()) :: map()
  def generate(lt_pubkey, lt_prikey, duration) when duration > 0 do
    Logger.info("Generating new temporary keypair...")
    now = DateTime.now!("Etc/UTC")
    min_t = DateTime.add(now, -@backdate_hours, :hour)
    max_t = DateTime.add(now, duration, :hour)

    {tmp_pubkey, tmp_prikey} = :crypto.generate_key(:eddsa, :ed25519)
    # Generate the CERT block
    dele = %{
      MINT: min_t,
      MAXT: max_t,
      PUBK: tmp_pubkey
    }

    lt_pubkey_hash = srv_hash(lt_pubkey)
    dele_ser = Roughtime.Wire.generate_message(dele)

    sig =
      :crypto.sign(:eddsa, :none, @delegation_context <> dele_ser, [lt_prikey, :ed25519])

    cert =
      Roughtime.Wire.generate_message(%{
        DELE: dele_ser,
        SIG: sig
      })

    Logger.info("Certificate generated:
    Long-term Public Key: #{Base.encode64(lt_pubkey)}
    Temp Public Key: #{Base.encode64(tmp_pubkey)}
    Min Time: #{DateTime.to_iso8601(min_t)}
    Max Time: #{DateTime.to_iso8601(max_t)}")

    %{
      cert: cert,
      min_t: min_t,
      max_t: max_t,
      prikey: tmp_prikey,
      pubkey: tmp_pubkey,
      lt_pubkey: lt_pubkey,
      lt_pubkey_hash: lt_pubkey_hash
    }
  end

  @doc """
  Return the pre-computed value of the `CERT` tag, to place into responses
  """
  @spec cert() :: binary()
  def cert, do: GenServer.call(__MODULE__, {:get, :cert})

  @doc """
  Return the current public key
  """
  @spec pubkey() :: binary()
  def pubkey, do: GenServer.call(__MODULE__, {:get, :pubkey})

  @doc """
  Return the first 32 bytes off the SHA-512 hash of the long term public key,
  required to handle logic for the SRV record type.
  """
  @spec lt_pubkey_hash() :: binary()
  def lt_pubkey_hash, do: GenServer.call(__MODULE__, {:get, :lt_pubkey_hash})

  @doc """
  Sign a given payload with the current temporary key. Returns the signature
  with the matching `CERT`, fetched together so a rotation can't split them.
  """
  @spec sign(binary()) :: {binary(), binary()}
  def sign(payload) do
    {prikey, cert} = GenServer.call(__MODULE__, :signing)
    {:crypto.sign(:eddsa, :none, @response_context <> payload, [prikey, :ed25519]), cert}
  end
end
