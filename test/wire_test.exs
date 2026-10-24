defmodule Roughtime.WireTest do
  use ExUnit.Case
  doctest Roughtime.Wire

  test "parses roughenough request" do
    payload =
      "test/fixtures/roughenough-request.bin"
      |> File.read!()

    message = Roughtime.Wire.parse(payload)

    for {tag, _value} <- message do
      if not Enum.member?(["PAD", :NONC, :VER], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end
  end

  test "rejects packets without a header or with the wrong length" do
    packet = Roughtime.Wire.generate(%{NONC: :crypto.strong_rand_bytes(32)})
    <<_header::binary-size(12), message::binary>> = packet

    assert_raise FunctionClauseError, fn -> Roughtime.Wire.parse(message) end
    assert_raise FunctionClauseError, fn -> Roughtime.Wire.parse(packet <> <<0>>) end
    assert_raise FunctionClauseError, fn -> Roughtime.Wire.parse(binary_part(packet, 0, 20)) end
  end

  test "parse draft-14 response" do
    payload =
      "test/fixtures/roughenough-response-14.bin"
      |> File.read!()

    message = Roughtime.Wire.parse(payload)

    for {tag, _value} <- message do
      if not Enum.member?([:SIG, :NONC, :TYPE, :PATH, :SREP, :CERT, :INDX], tag) do
        flunk("Contains unexpected tag #{tag}")
      end
    end

    assert byte_size(Map.get(message, :SIG)) == 64
  end

  test "generates valid request" do
    message = %{TEST: "test", VER: <<1, 0, 0, 0>>, NONC: :crypto.strong_rand_bytes(32)}
    generated = Roughtime.Wire.generate(message)
    result = Roughtime.Wire.parse(generated)
    {test_value, known} = Map.pop(message, :TEST)
    assert result == Map.put(known, "TEST", test_value)
  end

  test "generates nested structure" do
    message = %{
      VER: <<1, 0, 0, 0>>,
      INDX: <<0, 0, 0, 0>>,
      TYPE: <<0>>,
      PATH: "",
      SREP: %{
        ROOT: <<0>>,
        MIDP: DateTime.truncate(DateTime.now!("Etc/UTC"), :second),
        RADI: <<0>>
      },
      CERT: %{
        DELE: %{
          MINT: ~U[2000-01-01 00:00:00Z],
          MAXT: ~U[2049-12-31 23:59:59Z],
          PUBK: "public key"
        },
        SIG: <<0>>,
        NONC: :crypto.strong_rand_bytes(32)
      }
    }

    generated = Roughtime.Wire.generate(message)
    result = Roughtime.Wire.parse(generated)
    assert result == message

    classic_generated = Roughtime.Wire.generate(message)
    classic_result = Roughtime.Wire.parse(classic_generated)
    assert classic_result == message
  end

  test "generates and parses Unix timestamp" do
    dt = DateTime.truncate(DateTime.now!("Etc/UTC"), :second)
    unix_ts = Roughtime.Wire.generate_timestamp(dt)
    unix_got = Roughtime.Wire.parse_timestamp(unix_ts)
    assert unix_got == dt
  end

  describe "message_length/1" do
    test "reads the length from a real request header" do
      {req, _nonc} = Roughtime.Client.generate_request()
      <<header::binary-size(12), message::binary>> = req
      assert Roughtime.Wire.message_length(header) == {:ok, byte_size(message)}
    end

    test "accepts the maximum length" do
      max = Roughtime.Wire.max_length()
      assert {:ok, ^max} = Roughtime.Wire.message_length(<<"ROUGHTIM", max::little-32>>)
    end

    test "rejects a wrong identifier or short header" do
      assert {:error, _} = Roughtime.Wire.message_length(<<"ROUGHTIX", 1024::little-32>>)
      assert {:error, _} = Roughtime.Wire.message_length(<<"ROUGHTIM">>)
    end

    test "rejects zero and oversized lengths" do
      too_big = Roughtime.Wire.max_length() + 1
      assert {:error, _} = Roughtime.Wire.message_length(<<"ROUGHTIM", 0::little-32>>)
      assert {:error, _} = Roughtime.Wire.message_length(<<"ROUGHTIM", too_big::little-32>>)
    end
  end
end
