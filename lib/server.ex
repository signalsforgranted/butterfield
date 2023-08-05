require Logger

defmodule Roughtime.Server do
  @moduledoc false
  use GenServer

  @default_port 2002

  @doc """
  Starts the Roughtime server, parameters are placeholder and not implemented
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  @impl true
  def init(_params) do
    Logger.info("Starting server...")
    :gen_udp.open(@default_port, [:binary, active: true])
  end

  @impl true
  def handle_info({:udp, _socket, address, port, data}, state) do
    Logger.debug("#{:inet.ntoa(address)}:#{port} - #{data}")
    {:noreply, state}
  end
end
