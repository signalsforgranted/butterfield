defmodule Roughtime.Wire do
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

  @doc """
  Parse a packet.
  Returns a list of lists, each with the tag as first element and value as second.
  """
  @spec parse(binary()) :: list()
  def parse(packet) when is_binary(packet) do
    # Parse header and separate out message
    <<
      @protocol_identifier::unsigned-little-integer-size(64),
      length::unsigned-little-integer-size(32),
      message::binary
    >> = packet

    # It's possible we got more than the announced length, so truncate it...
    message = <<message::binary-size(length)>>

    # Parse message block, everything here is 32 bit aligned, hence why you'll
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

      [tag, :binary.part(values, Enum.at(offset, 0), len)]
    end)
  end

  @doc """
  Wrap the message into the rest of the structure for sending. Message must be
  binary and already serialised.
  """
  @spec generate_packet(binary()) :: binary()
  def generate_packet(message) do
    <<
      @protocol_identifier::unsigned-little-integer-size(64),
      byte_size(message)::unsigned-little-integer-size(32),
      message::binary
    >>
  end
end
