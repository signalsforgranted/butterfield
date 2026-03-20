defmodule Roughtime.TCPHandler do
  @moduledoc false
  require Logger
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
  def init(state) do
    Logger.info("Starting roughtime server on TCP port #{default_port()}...")

    {:ok, socket} =
      :gen_tcp.listen(default_port(), [
        :binary,
        active: true,
        reuseaddr: true,
        backlog: 4096 # TODO This should be configuration
      ])

    {:ok, %{state | socket: socket}}
  end

  @impl true
  def handle_info(:accept, %{socket: socket} = state) do
    {:ok, _} = :gen_tcp.accept(socket)
    Logger.debug "Connection from #{socket}"
    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, state) do
    case Roughtime.Server.handle_request(data) do
      {:ok, res} -> :gen_tcp.send(socket, res)
      {:error, reason} -> Logger.debug(reason)
    end

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}
end
