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

  # Connections waiting to be accepted before the OS starts refusing them.
  @spec backlog() :: integer()
  defp backlog, do: Application.fetch_env!(:butterfield, :backlog)

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
        backlog: backlog()
      ])

    accept(listener)
  end

  defp accept(listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        hand_off(socket)

      # Usually out of file descriptors (:emfile). Crashing would restart the
      # listener into the same error until the supervisor gives up, so wait
      # and try again. :closed isn't matched: the listener is gone, so go on
      # and crash.
      {:error, reason} when reason != :closed ->
        Logger.warning("TCP accept failed: #{inspect(reason)}")
        Process.sleep(100)
    end

    accept(listener)
  end

  defp hand_off(socket) do
    case Task.Supervisor.start_child(Roughtime.TCPConnections, fn -> await(socket) end) do
      {:ok, pid} ->
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, :socket)

      {:error, :max_children} ->
        Logger.debug("Too many TCP connections, closing new one")
        :gen_tcp.close(socket)
    end
  end

  defp await(socket) do
    receive do
      :socket -> serve(socket)
    end
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
