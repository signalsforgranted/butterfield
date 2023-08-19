defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "parses roughenough request" do
    payload =
      "test/fixtures/roughenough-request.bin"
      |> File.read!()

    message = Roughtime.Wire.parse_request(payload)

    for {tag, _value} <- message do
      if not Enum.member?(["PAD", "NONC", "VER"], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  test "parses roughenough response" do
    payload =
      "test/fixtures/roughenough-response.bin"
      |> File.read!()

    message = Roughtime.Wire.parse_message(payload)

    for {tag, _value} <- message do
      # This list matches what roughenough provides, but does not appear to
      # match what draft -05 or -07 produce.
      if not Enum.member?(["INDX", "CERT", "PATH", "SIG", "SREP"], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  test "parse google request" do
    payload =
      "test/fixtures/google-request.bin"
      |> File.read!()

    message = Roughtime.Wire.parse_google(payload)

    for {tag, _value} <- message do
      if not Enum.member?(["PAD", "NONC"], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end

    assert byte_size(Map.get(message, "NONC")) == 64
  end
end
