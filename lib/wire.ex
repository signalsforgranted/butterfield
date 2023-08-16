defmodule Roughtime.Wire do
  @moduledoc """
  Handle all of the parsing and generation of packets.
  """
  # "ROUGHTIM"
  @protocol_identifier 0x524f55474854494d

  @doc """
  Roughtime packets are comprised of a constant header, the length (as they are
  padded to MTU)
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
  """
  @spec parse_packet(binary()) :: any()
  def parse_packet(packet) do
    <<
      @protocol_identifier::unsigned-big-integer-size(64),
      length::unsigned-big-integer-size(32),
      message::binary
    >> = packet
	[length, message]
  end

  @doc """
  Wrap the message into the rest of the structure for sending. Message must be
  binary and already serialised.
  """
  @spec generate_packet(binary()) :: binary()
  def generate_packet(message) do
    <<
      @protocol_identifier::unsigned-big-integer-size(64),
      byte_size(message)::unsigned-big-integer-size(32),
      message::binary
    >>
  end

  @doc """
  Messages are the main payload, and contain the following structure:
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
  def parse_message(message) when is_binary(message) do
    <<
      total_pairs::unsigned-big-integer-size(32),
      offsets_tags_values::binary
    >> = message

    offset_len = (total_pairs - 1) * 32
    # FIXME: Handle <= 1 tag, not permitted but could happen
    <<
      offsets::unsigned-big-integer-size(offset_len),
      tags::unsigned-big-integer-size(total_pairs * 32),
      _values::binary
    >> = offsets_tags_values

    # FIXME: more pragmatic way of doing this
    _offsets = for <<offset::32 <- offsets>>, do: offset
    _tags = for <<tag::32 <- tags>>, do: tag

    # Tags can be repeated, so a list of kv pairs makes sense
  end

  def generate_message() do
  end
end
