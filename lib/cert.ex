defmodule Roughtime.CertBox do
  use Agent

  @moduledoc """
  Handle the ed25519 certificate. This Agent aims to keep the private (and
  public) keys in memory but try to not expose the private key. This of course
  will not stop any direct memory attacks or privileged attackers able to
  inspect the running BEAM process, but this may just prevent the author from
  writing leaky code.
  """
  @spec start_link(list()) :: Agent.on_start()
  def start_link(certs \\ []) do
    Agent.start_link(fn -> certs end, name: __MODULE__)
  end

  @doc "Return _only_ the public key component."
  @spec public_key() :: binary()
  def public_key do
    Enum.at(Agent.get(__MODULE__, & &1), 0)
  end

  @doc """
  No keys? No problem, generate a set and update state. This is only useful if
  you are needing ephemeral keys, such as during testing.
  ⚠️  **This will replace any keys already in place! **
  """
  @spec generate() :: :ok
  def generate do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    Agent.update(__MODULE__, fn _state -> [public_key, private_key] end)
  end

  @doc "Sign a given payload with the key material."
  @spec sign(any()) :: binary()
  def sign(payload) do
    [public_key, private_key] = Agent.get(__MODULE__, & &1)
    # :public_key shows up after compile, this suppresses warnings
    apply(:public_key, :sign, [
      payload,
      :ignored,
      {:ed_pri, :ed25519, public_key, private_key},
      []
    ])
  end
end
