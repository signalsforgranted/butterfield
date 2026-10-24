defmodule Roughtime.Batcher do
  @moduledoc """
  Collects requests that arrive together and answers them with one signature.

  A batch is signed as soon as there's nothing left waiting in the mailbox, or
  when it reaches the configured batch size, so a quiet server adds no delay
  and a busy one signs many requests at once.
  """
  use GenServer

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Add a validated request to the current batch.
  This blocks until the batch has been signed, then returns the encoded response.
  """
  @spec respond(binary(), binary()) :: binary()
  def respond(request, nonce) do
    GenServer.call(__MODULE__, {:respond, request, nonce})
  end

  @impl true
  def init(_opts) do
    {:ok, %{size: Application.fetch_env!(:butterfield, :batch_size), batch: []}}
  end

  @impl true
  def handle_call({:respond, request, nonce}, from, state) do
    batch = [{from, request, nonce} | state.batch]

    if length(batch) >= state.size,
      do: {:noreply, %{state | batch: flush(batch)}},
      else: {:noreply, %{state | batch: batch}, 0}
  end

  # The 0 timeout above fires once the mailbox is empty.
  @impl true
  def handle_info(:timeout, state) do
    {:noreply, %{state | batch: flush(state.batch)}}
  end

  defp flush(batch) do
    batch = Enum.reverse(batch)
    responses = Roughtime.Server.sign(for {_from, request, nonce} <- batch, do: {request, nonce})

    for {{from, _request, _nonce}, response} <- Enum.zip(batch, responses) do
      GenServer.reply(from, response)
    end

    []
  end
end
