defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "parses roughenough request" do
    payload =
      "test/fixtures/roughenough-request.bin"
      |> File.read!()

    message = Roughtime.Wire.parse(payload)

    for {tag, _value} <- message do
      if not Enum.member?([:PAD, :NONC, :VER], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  test "parses roughenough response" do
    payload =
      "test/fixtures/roughenough-response-direct.bin"
      |> File.read!()

    message = Roughtime.Wire.parse(payload)

    for {tag, _value} <- message do
      # This list matches what roughenough provides, but does not appear to
      # match what draft -05 or -07 produce.
      if not Enum.member?([:INDX, :CERT, :PATH, :SIG, :SREP, :VER], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  test "parses cloudflare response" do
    payload =
      "test/fixtures/cloudflare-response.bin"
      |> File.read!()

    message = Roughtime.Wire.parse(payload)

    for {tag, _value} <- message do
      # This list matches what roughenough provides, but does not appear to
      # match what draft -05 or -07 produce.
      if not Enum.member?([:INDX, :CERT, :PATH, :SIG, :SREP, :VER], tag) do
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
      if not Enum.member?([:PAD, :NONC], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end

    assert byte_size(Map.get(message, :NONC)) == 64
  end

  test "generates valid request" do
    message = %{TEST: "test", VER: <<1, 0, 0, 0>>, NONC: :crypto.strong_rand_bytes(64)}
    generated = Roughtime.Wire.generate_request(message)
    result = Roughtime.Wire.parse(generated)
    assert result == message
  end

  test "generates nested structure" do
    message = %{
      VER: <<1, 0, 0, 0>>,
      INDX: <<0, 0, 0, 0>>,
      PATH: "",
      SREP: %{
        ROOT: <<0>>,
        MIDP: <<0>>,
        RADI: <<0>>
      },
      CERT: %{
        DELE: %{
          MINT: <<0>>,
          MAXT: <<0>>,
          PUBK: "public key"
        },
        SIG: <<0>>,
        NONC: :crypto.strong_rand_bytes(64)
      }
    }

    generated = Roughtime.Wire.generate_request(message)
    result = Roughtime.Wire.parse(generated)
    assert result == message
  end

  test "parses Unix timestamp" do
    dt = DateTime.now!("Etc/UTC")
    unix_test = <<DateTime.to_unix(dt, :microsecond)::unsigned-little-integer-size(64)>>
    unix_got = Roughtime.Wire.parse_timestamp(unix_test)
    assert unix_got == dt
  end

  test "parses MJD timestamp" do
    mjd_test = <<205, 24, 140, 230, 18, 23, 235, 0>>
    {:ok, expected, 0} = DateTime.from_iso8601("2023-08-27T22:32:57.352397Z")
    mjd_got = Roughtime.Wire.parse_timestamp(mjd_test)
    assert mjd_got == expected
  end
end
