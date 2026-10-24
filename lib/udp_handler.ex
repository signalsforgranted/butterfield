defmodule Roughtime.UDPHandler do
  @moduledoc false
  require Logger
  use GenServer

  # Datagrams delivered to us before the socket pauses and waits for setopts/2,
  # so a flood of requests can't fill the mailbox.
  @active 100

  # Bursts of replies cause bursts of requests; the kernel default can drop them.
  @recbuf 4 * 1024 * 1024

  @spec default_port() :: integer()
  defp default_port, do: Application.fetch_env!(:butterfield, :port)

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  @impl true
  def init(_params) do
    Logger.info("Starting roughtime server on UDP port #{default_port()}...")
    :gen_udp.open(default_port(), [:binary, active: @active, recbuf: @recbuf])
  end

  # Each request waits for its batch in its own task, so we can keep receiving.
  @impl true
  def handle_info({:udp, socket, address, port, data}, socket) do
    case Task.Supervisor.start_child(Roughtime.UDPRequests, fn ->
           respond(socket, address, port, data)
         end) do
      {:ok, _pid} -> :ok
      {:error, :max_children} -> Logger.debug("Too many UDP requests in flight, dropping")
    end

    {:noreply, socket}
  end

  def handle_info({:udp_passive, socket}, socket) do
    :ok = :inet.setopts(socket, active: @active)
    {:noreply, socket}
  end

  defp respond(socket, address, port, data) do
    case Roughtime.Server.handle_request(data) do
      {:ok, res} -> :gen_udp.send(socket, address, port, res)
      {:error, reason} -> Logger.debug("Ignoring #{:inet.ntoa(address)}:#{port}: #{reason}")
    end
  end
end
