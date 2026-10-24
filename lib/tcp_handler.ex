defmodule Roughtime.TCPHandler do
  @moduledoc false
  require Logger
  use Task, restart: :permanent

  # Close connections that have been idle this long, in milliseconds.
  @spec idle_timeout() :: integer()
  defp idle_timeout, do: Application.fetch_env!(:butterfield, :idle_timeout)

  # Port to listen to - we always use the same as UDP.
  @spec default_port() :: integer()
  defp default_port, do: Application.fetch_env!(:butterfield, :port)

  def start_link(_params) do
    Task.start_link(__MODULE__, :listen, [])
  end

  def listen do
    Logger.info("Starting roughtime server on TCP port #{default_port()}...")

    {:ok, listener} =
      :gen_tcp.listen(default_port(), [
        :binary,
        active: false,
        reuseaddr: true,
        # TODO This should be configuration
        backlog: 4096
      ])

    accept(listener)
  end

  defp accept(listener) do
    {:ok, socket} = :gen_tcp.accept(listener)
    {:ok, pid} = Task.Supervisor.start_child(Roughtime.TCPConnections, fn -> serve(socket) end)
    :ok = :gen_tcp.controlling_process(socket, pid)
    accept(listener)
  end

  defp serve(socket) do
    timeout = idle_timeout()

    with {:ok, header} <- :gen_tcp.recv(socket, 12, timeout),
         {:ok, length} <- Roughtime.Wire.message_length(header),
         {:ok, message} <- :gen_tcp.recv(socket, length, timeout),
         {:ok, res} <- Roughtime.Server.handle_request(header <> message),
         :ok <- :gen_tcp.send(socket, res) do
      serve(socket)
    else
      error ->
        Logger.debug("Closing TCP connection: #{inspect(error)}")
        :gen_tcp.close(socket)
    end
  end
end
