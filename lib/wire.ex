defmodule Roughtime.Wire do
  import Bitwise

  @moduledoc """
  Handle all of the parsing and generation of packets.

  Roughtime packets are comprised of a constant header, the length (as they are
  padded to MTU or nearabouts) and the rest of the payload.

  ```
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                  0x4d49544847554f52 (uint64)                  |
  |                        ("ROUGHTIM")                           |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                    Message length (uint32)                    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                               |
  .                                                               .
  .                      Roughtime message                        .
  .                                                               .
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  ```

  Messages are the main section of the payload, and contain the following:
  ```
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                   Number of pairs (uint32)                    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                               |
  .                                                               .
  .                     N-1 offsets (uint32)                      .
  .                                                               .
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                               |
  .                                                               .
  .                        N tags (uint32)                        .
  .                                                               .
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                               |
  .                                                               .
  .                            Values                             .
  .                                                               .
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  ```
  """
  # "ROUGHTIM"
  @protocol_identifier 0x4D49544847554F52

  # List of tags which can deep nest with other tags
  @nestable_tags [:SREP, :CERT, :DELE]

  # Guestimate timestamp to guess which epoch, see parse_timestamp/1
  # This integer represents 2099-12-31T23:59:59Z
  @timestamp_guestimate 4_102_444_799_000_000

  # Largest timestamp supported by DateTime as microseconds from Unix epoch
  # This integer represents 9999-12-31T23:59:59Z
  @timestamp_max 253_402_300_799_000_000

  # Modified Julian Date
  @mjd ~D[1858-11-17]

  # Days between Modified Julian Day (1858-11-17) and Unix Epoch (1970-01-01)
  @mjd_offset 40_587

  @doc """
  Parse a request packet.
  Returns a list of lists, each with the tag as first element and value as second.
  """
  @spec parse(binary()) :: map()
  def parse(packet) when is_binary(packet) do
    # Parse header and separate out message
    <<
      @protocol_identifier::unsigned-little-integer-size(64),
      length::unsigned-little-integer-size(32),
      message::binary
    >> = packet

    # It's possible we got more than the announced length, so truncate it...
    message = <<message::binary-size(length)>>
    parse_message(message)
  end

  @doc """
  Parse a roughtime message.
  Returns a map with tags as key, and values respectively.
  """
  @spec parse_message(binary()) :: map()
  def parse_message(message) when is_binary(message) do
    # Everything here is 32 bit aligned, hence why you'll
    # see that used a lot in this section.
    <<
      total_pairs::unsigned-little-integer-size(32),
      offsets_tags_values::binary
    >> = message

    offset_len = (total_pairs - 1) * 32
    tags_len = total_pairs * 32

    <<
      offsets::bitstring-size(offset_len),
      tags::bitstring-size(tags_len),
      values::binary
    >> = offsets_tags_values

    offsets = for <<offset::unsigned-little-integer-size(32) <- offsets>>, do: offset
    tags = for <<tag::bitstring-size(32) <- tags>>, do: tag

    # Append and prepend start end end values, to make scanning more logical
    offsets = [0 | offsets] ++ [byte_size(values)]
    offsets = Enum.chunk_every(offsets, 2, 1, :discard)

    offsets
    |> Enum.with_index()
    |> Enum.map(fn {offset, index} ->
      # :binary.part/3 wants start and length, not start and end
      len = Enum.at(offset, 1) - Enum.at(offset, 0)

      # Remove null byte so we treat all tags like strings
      <<name::binary-size(3), last::binary>> = Enum.at(tags, index)
      # For a long time 3-byte tags could have either 0x00 or 0xff
      tag =
        if last == <<0>> or last == <<255>> do
          name
        else
          Enum.at(tags, index)
        end

      # Nest into tags that may contain other tags
      value =
        if Enum.member?(@nestable_tags, String.to_atom(tag)) do
          parse_message(:binary.part(values, Enum.at(offset, 0), len))
        else
          :binary.part(values, Enum.at(offset, 0), len)
        end

      # Parse the value out where we require non-binary types used
      value =
        case tag do
          t when t in ["MIDP", "MINT", "MAXT"] -> parse_timestamp(value)
          _ -> value
        end

      [tag, value]
    end)
    |> Map.new(fn [k, v] -> {String.to_existing_atom(k), v} end)
  end

  @doc """
  Parse an older, or Google formatted payload.
  Unlike newer I-D versions, requets do not have the protocol identifier,
  Amongst other differences.
  """
  @spec parse_google(binary()) :: map()
  def parse_google(message) do
    parse_message(message)
  end

  @doc """
  Wrap the message into the rest of the structure for sending reuqests.
  """
  @spec generate_request(map()) :: binary()
  def generate_request(message) do
    payload = generate_message(message)

    <<
      @protocol_identifier::unsigned-little-integer-size(64),
      byte_size(payload)::unsigned-little-integer-size(32),
      payload::binary
    >>
  end

  @doc """
  Keys should be valid tags as strings and not atoms, without any null byte
  padding if shorter than 4 bytes in length.
  The maximum length should be no greater than the originating request packet -
  this in turn will define how much padding will be applied.
  """
  @spec generate_message(map()) :: binary()
  def generate_message(message) when is_map(message) do
    total_pairs = length(Map.keys(message))

    message =
      Enum.map(message, fn {tag, value} ->
        # Values have to processed at same time as tags because we need to know
        # the tag at time for validation.
        value =
          if Enum.member?(@nestable_tags, tag) and is_map(value) do
            generate_message(value)
          else
            # We're too nested deep, this code needs to be refactored
            case tag do
              t when t in [:MIDP, :MINT, :MAXT] -> generate_timestamp(value)
              _ -> value
            end
          end

        {tag, value}
      end)

    {tags, values} = Enum.unzip(message)

    # Tags - 3 byte tags need padding with 0x0.
    tags =
      Enum.map(tags, fn tag ->
        tag = Atom.to_string(tag)

        if String.length(tag) == 3 do
          tag <> <<0>>
        else
          tag
        end
      end)

    # increment for the length of each respective value.
    offsets =
      values
      |> Enum.map(fn value -> byte_size(value) end)
      # N-1, we don't need to carry last length
      |> Enum.drop(-1)

    offsets =
      Enum.scan(offsets, &+/2)
      |> Enum.map(fn offset -> <<offset::unsigned-little-integer-size(32)>> end)

    <<total_pairs::unsigned-little-integer-size(32)>> <>
      :erlang.list_to_binary(offsets) <>
      :erlang.list_to_binary(tags) <>
      :erlang.list_to_binary(values)
  end

  @doc """
  Parse timestamp values.
  Timestamps are either provided with UNIX Epoch (midnight 1970-01-01) values,
  or they use Modified Julian Date with today's total microseconds interleaved.
  It's also possible for implementations to juse use maximum 64bit integer value
  as well, particularly for expiration or unknown values. To figure out which is
  which, we assume any timestamp greater than UNIX epoch but lower than highest
  date is MJD, and handle those greater than the highest date is invalid.
  """
  @spec parse_timestamp(binary()) :: Calendar.datetime()
  def parse_timestamp(timestamp) do
    <<ts_int::unsigned-little-integer-size(64)>> = timestamp

    {:ok, dt} =
      cond do
        # Likely Unix Epoch
        ts_int < @timestamp_guestimate ->
          DateTime.from_unix(ts_int, :microsecond)

        # Likely MJD
        ts_int > @timestamp_guestimate and ts_int < @timestamp_max ->
          # Most meaningful 3 bytes are MJD, remaining 5 are msec of current day.
          mjd_day = ts_int >>> 40
          msec = ts_int &&& 0xFFFFFFFFFF
          today = (mjd_day - @mjd_offset) * 86_400_000_000
          DateTime.from_unix(today + msec, :microsecond)

        # Likely invalid
        ts_int > @timestamp_max ->
          DateTime.from_unix(@timestamp_max, :microsecond)
      end

    dt
  end

  @doc """
  Generate a timestamp
  """
  @spec generate_timestamp(Calendar.datetime(), atom()) :: binary()
  def generate_timestamp(timestamp, format \\ :unix) do
    case format do
      :unix ->
        unix_secs = DateTime.to_unix(timestamp, :microsecond)
        <<unix_secs::unsigned-little-integer-size(64)>>

      :mjd ->
        mjd_day = Date.diff(DateTime.to_date(timestamp), @mjd)
        {secs, msecs} = Time.to_seconds_after_midnight(DateTime.to_time(timestamp))
        msecs = secs * 1_000_000 + msecs
        ts = (mjd_day <<< 40) + msecs
        <<ts::unsigned-little-integer-size(64)>>
    end
  end
end
