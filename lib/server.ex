require Logger

defmodule Roughtime.Server do
  @moduledoc false
  use GenServer

  defp default_port do
    Application.fetch_env!(:butterfield, :port)
  end

  defp public_key do
    Application.fetch_env!(:butterfield, :public_key)
  end

  defp private_key do
    Application.fetch_env!(:butterfield, :private_key)
  end

  @doc """
  Starts the Roughtime server, parameters are placeholder and not implemented
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  @impl true
  def init(_params) do
    if public_key() && private_key() do
      Logger.info("Using Public Key: #{public_key()}")

      Roughtime.CertBox.update(
        Base.decode64!(public_key()),
        Base.decode64!(private_key())
      )
    else
      Logger.warning("No keys found, generating ephemeral pair...")
      Roughtime.CertBox.generate()
    end

    Logger.info("Starting roughtime server on port #{default_port()}...")
    :gen_udp.open(default_port(), [:binary, active: true])
  end

  @impl true
  def handle_info({:udp, _socket, address, port, _data}, state) do
    Logger.debug("Request from #{:inet.ntoa(address)}:#{port}")
    {:noreply, state}
  end
end
