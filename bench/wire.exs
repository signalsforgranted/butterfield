Incendium.Application.start(nil, nil)

Incendium.run(
  %{
    "parse" => fn payload -> Roughtime.Wire.parse(payload) end
  },
  inputs: %{
    "roughenough-req" => File.read!("test/fixtures/roughenough-request.bin"),
    "roughenough-res" => File.read!("test/fixtures/roughenough-response.bin"),
    "cloudflare-res" => File.read!("test/fixtures/cloudflare-response.bin")
  },
  title: "Butterfield Benchmark"
)
