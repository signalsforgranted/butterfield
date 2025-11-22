defmodule Roughtime.ApplicationTest do
  use ExUnit.Case
  doctest Roughtime.Application

  @moduletag :capture_log
  test "doesn't fall over with a stick in the spokes" do
    {:ok, _pid} = Roughtime.Application.start(:normal, [])
  end
end
