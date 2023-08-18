defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "parses -07 request" do
    payload =
      "test/fixtures/-07-request.bin"
      |> File.read!()

    message = Roughtime.Wire.parse(payload)

    for tag_value <- message do
      if not Enum.member?(["PAD", "NONC", "VER"], Enum.at(tag_value, 0)) do
        flunk("Contains unexpected tag #{Enum.at(tag_value, 0)}")
      end
    end
  end
end
