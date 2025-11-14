#!/usr/bin/env elixir

help = """
This script is more of a developer tool that will take a given file, ideally the
packet data of a Roughtime request or response from your packet capture tool of
choice and parsed, which can be very helpful when debugging issues.

Arguments:

  --file <filename>
    Will read this file it and dump out what is parsed

  --help
    Show this lovely information, of course

Example Usage:

  mix run --no-start script/roughdump.exs --file test.bin

"""

{parsed, _args, _invalid} = OptionParser.parse(System.argv(),switches: [help: :boolean, file: :string])

if Keyword.has_key?(parsed, :help) do
  IO.puts(help)
  exit({:shutdown, 0})
end

payload = Keyword.get(parsed, :file) |> File.read!()
message = Roughtime.Wire.parse(payload)

IO.inspect(message, pretty: true, limit: :infinity)
