defmodule Roughtime.BatcherTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup do
    start_supervised!({Roughtime.CertBox, %{}})
    %{batcher: start_supervised!(Roughtime.Batcher)}
  end

  # Send `count` requests while the Batcher is paused, so they all wait in its
  # mailbox, then let it go and collect the parsed responses.
  defp send_together(batcher, count) do
    :sys.suspend(batcher)
    requests = for _ <- 1..count, do: Roughtime.Client.generate_request()

    tasks =
      for {request, _nonce} <- requests do
        Task.async(fn -> Roughtime.Server.handle_request(request) end)
      end

    wait_for_mailbox(batcher, count)
    :sys.resume(batcher)

    for {{request, nonce}, task} <- Enum.zip(requests, tasks) do
      {:ok, response} = Task.await(task)
      {request, nonce, Roughtime.Wire.parse(response)}
    end
  end

  defp wait_for_mailbox(pid, count) do
    unless Process.info(pid, :message_queue_len) == {:message_queue_len, count} do
      Process.sleep(1)
      wait_for_mailbox(pid, count)
    end
  end

  test "requests arriving together share one signature", %{batcher: batcher} do
    responses = send_together(batcher, 50)

    assert responses |> Enum.map(fn {_, _, res} -> res[:SIG] end) |> Enum.uniq() |> length() == 1

    assert responses |> Enum.map(fn {_, _, res} -> res[:INDX] end) |> Enum.uniq() |> length() ==
             50

    for {request, nonce, res} <- responses do
      assert res[:NONC] == nonce
      assert Roughtime.Client.verify_path(request, res[:INDX], res[:PATH], res[:SREP][:ROOT])
    end
  end

  test "batches are capped at the batch size", %{batcher: batcher} do
    responses = send_together(batcher, 130)
    roots = responses |> Enum.map(fn {_, _, res} -> res[:SREP][:ROOT] end) |> Enum.uniq()

    # 64 + 64 + 2
    assert length(roots) == 3
  end

  test "a lone request is answered straight away" do
    {request, nonce} = Roughtime.Client.generate_request()
    assert {:ok, response} = Roughtime.Server.handle_request(request)
    res = Roughtime.Wire.parse(response)

    assert res[:NONC] == nonce
    assert res[:PATH] == ""
  end
end
