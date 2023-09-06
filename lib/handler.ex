require Logger

defmodule Roughtime.Handler do
  @moduledoc false
  use GenServer

  @spec default_port() :: integer()
  defp default_port do
    Application.fetch_env!(:butterfield, :port)
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
    Logger.info("Starting roughtime server on port #{default_port()}...")
    :gen_udp.open(default_port(), [:binary, active: true])
  end

  @impl true
  def handle_info({:udp, _socket, address, port, _data}, state) do
    Logger.debug("Request from #{:inet.ntoa(address)}:#{port}")
    {:noreply, state}
  end
end
