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
  """

  @response_context "RoughTime v1 response signature"
  @delegation_context "RoughTime v1 delegation signature"

  @spec cert_duration() :: integer()
  defp cert_duration do
    Application.fetch_env!(:butterfield, :cert_duration)
  end

  @spec start_link(any()) :: Agent.on_start()
  def start_link(_opts) do
    {:ok, pid} = Agent.start_link(fn -> %{} end, name: __MODULE__)
    # Minimise key material from leaking in crash dumps
    #Process.flag(pid, :sensitive, true)
    {:ok, pid}
  end

  @doc """
  Either at start up before responding to requests or at some point on an
  existing running service generate a temporary keypair, sign and pre-generate
  the response payload. If the private key at `:butterfield.private_key` is not
  set, then we will generate a temporary long term key that will be discarded in
  order to generate and sign the temporary keys used in the certificate.

  ⚠️  **This will replace any keys already in place! **
  """
  @spec generate(any()) :: :ok
  def generate(prikey \\ nil) do

    Logger.info("Generating new temporary keypair...")
    min_t = DateTime.now!("Etc/UTC")
    max_t = DateTime.add(min_t, cert_duration(), :day)

    {temp_pubkey, temp_prikey} = :libdecaf_curve25519.eddsa_keypair()
    # Generate the CERT block
    cert = %{
      MINT: min_t,
      MAXT: max_t,
      PUBK: temp_pubkey
    }

    cert_ser = Roughtime.Wire.generate_message(cert)
    sig = :libdecaf_curve25519.ed25519ctx_sign(cert_ser, prikey, @delegation_context)
    cert = Roughtime.Wire.generate_message(%{
      CERT: %{
        SIG: sig,
        DELE: cert_ser
      }
    })

    Logger.info("Certificate generated:\n
    Public Key: #{Base.encode64(temp_pubkey)}\n
    Min Time: #{DateTime.to_iso8601(min_t)}\n
    Max Time: #{DateTime.to_iso8601(max_t)}")

    Agent.update(__MODULE__, fn _state -> %{
      cert: cert,
      min_t: min_t,
      max_t: max_t,
      prikey: temp_prikey,
      pubkey: temp_pubkey
    } end)
  end

  @doc """
  Return the pre-computed value of the `CERT` tag, to place into responses
  """
  @spec cert() :: binary()
  def cert do
    Map.fetch!(Agent.get(__MODULE__, & &1), :cert)
  end

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

  def verify(sig, payload, pubkey) do
    :libdecaf_curve25519.ed25519ctx_verify(sig, payload, pubkey)
  end
end
