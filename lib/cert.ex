require Logger

defmodule Roughtime.CertBox do
  use Agent

  @moduledoc """
  Handle and generate key material.

  Roughtime has the concept of two sets of key material - the "long term key"
  which is just a public/private keypair which is provided via the Application
  runtime configuration, and a temporary keypair which has some defined time
  range of validity that is generated at service start up. When the service
  initialises, we generate a new temporary keypair and sign it with the
  long-term key, subsequently no longer using the long term key material. All
  responses are then signed with the temporary key. A new temporary key can be
  generated at a later time (important for long-running instances that exceed
  the `MAXT` value, but require the long-term private key again to do so.

  "Volat tempus"
  """

  # Default duration of temporary certificates made off the long-term
  @default_cert_duration 90

  # Context Strings are required when signing messages, thus we are very
  # specifically using "contextual" Ed25519 or otherwise known as Ed25519ctx.
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

  """
  @spec start_link(map()) :: Agent.on_start()
  def start_link(keys) do
    # We don't have keys, make temp...
    {lt_pubkey, lt_prikey} =
      if Map.get(keys, :lt_prikey) != nil and Map.get(keys, :lt_pubkey) != nil do
        dc_prikey = Base.decode64!(Map.get(keys, :lt_prikey))
        dc_pubkey = Base.decode64!(Map.get(keys, :lt_pubkey))
        {dc_pubkey, dc_prikey}
      else
        Logger.warning("No long-term keys provided, generating some")
        :libdecaf_curve25519.eddsa_keypair()
      end

    duration = Map.get(keys, :duration, @default_cert_duration)

    keys = generate(lt_prikey, lt_pubkey, duration)
    Agent.start_link(fn -> keys end, name: __MODULE__)
  end

  @doc """
  Either at start up before responding to requests or at some point on an
  existing running service generate a temporary keypair, sign and pre-generate
  the response payload. If the private key at `:butterfield.private_key` is not
  set, then we will generate a temporary long term key that will be discarded in
  order to generate and sign the temporary keys used in the certificate.

  ⚠️  **This will replace any keys already in place! **
  """
  @spec generate(binary(), binary(), pos_integer()) :: map()
  def generate(lt_prikey, lt_pubkey, duration) do
    Logger.info("Generating new temporary keypair...")
    min_t = DateTime.now!("Etc/UTC")
    max_t = DateTime.add(min_t, duration, :day)

    {tmp_pubkey, tmp_prikey} = :libdecaf_curve25519.eddsa_keypair()
    # Generate the CERT block
    cert = %{
      MINT: min_t,
      MAXT: max_t,
      PUBK: tmp_pubkey
    }

    cert_ser = Roughtime.Wire.generate_message(cert)
    sig = :libdecaf_curve25519.ed25519ctx_sign(cert_ser, lt_prikey, @delegation_context)

    cert =
      Roughtime.Wire.generate_message(%{
        CERT: %{
          SIG: sig,
          DELE: cert_ser
        }
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
      lt_pubkey: lt_pubkey
    }
  end

  @doc """
  Runs `Roughtime.CertBox.generate/1` but will generate a very ephemeral "long
  term" key. This is useful for firing up the server in development or testing,
  but should be avoided in runtime.

  ⚠️  **This keypair is not persisted anywhere!**
  """
  @spec generate() :: :ok
  def generate do
    {lt_pubkey, lt_prikey} = :libdecaf_curve25519.eddsa_keypair()
    Logger.warning("No long term key was provided, making a temp key instead")
    Logger.warning("Public Key: #{Base.encode64(lt_pubkey)}")
    generate(lt_prikey, lt_pubkey, @default_cert_duration)
  end

  @doc """
  Return the pre-computed value of the `CERT` tag, to place into responses
  """
  @spec cert() :: binary()
  def cert do
    Map.fetch!(Agent.get(__MODULE__, & &1), :cert)
  end

  @doc """
  Return the current public key
  """
  @spec pubkey() :: binary()
  def pubkey do
    Map.fetch!(Agent.get(__MODULE__, & &1), :pubkey)
  end

  @doc """
  Sign a given payload with the current key material kept in state.
  """
  @spec sign(binary()) :: binary()
  def sign(payload) do
    prikey = Map.fetch!(Agent.get(__MODULE__, & &1), :prikey)
    :libdecaf_curve25519.ed25519ctx_sign(payload, prikey, @response_context)
  end
end
