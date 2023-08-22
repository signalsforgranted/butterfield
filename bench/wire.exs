
Benchee.run(
  %{
    "parse_response" => fn payload -> Roughtime.Wire.parse_message(payload) end
  },
  inputs: %{
    "roughenough" => File.read!("test/fixtures/roughenough-response.bin"),
    "google" => File.read!("test/fixtures/google-request.bin")
  }
)
