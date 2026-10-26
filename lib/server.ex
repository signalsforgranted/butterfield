defmodule Roughtime.Server do
  @moduledoc """
  Roughtime server logic without network interactions.

  "Quid celerius tempore?"
  """

  # Which version we support - this is version 1 (RFC 10049).
  # This value should match Roughtime.Wire.version().
  @supported_version <<1, 0, 0, 0>>

  # Default value for RADI until we know better precision
  @default_precision <<3, 0, 0, 0>>

  @doc """
  Process a roughtime request.

  Returns:
    {:ok, binary()} with encoded payload to return to client or,
    {:error, string()} with a human readable reason why the request failed.
  """
  @spec handle_request(binary()) :: {:ok, binary()} | {:error, String.t()}
  def handle_request(request) when is_binary(request) do
    with {:ok, req} <- parse(request),
         :ok <- check_version(Map.get(req, :VER)),
         :ok <- check_type(Map.get(req, :TYPE)),
         :ok <- check_srv(Map.get(req, :SRV)),
         :ok <- check_nonce(Map.get(req, :NONC)),
         res = Roughtime.Batcher.respond(request, Map.get(req, :NONC)),
         :ok <- check_size(res, request) do
      {:ok, res}
    end
  end

  defp parse(request) do
    {:ok, Roughtime.Wire.parse(request)}
  rescue
    _ -> {:error, "Malformed packet"}
  end

  defp check_version(<<1::unsigned-little-integer-size(32), _::binary>>), do: :ok
  defp check_version(<<_::binary-size(4), rest::binary>>), do: check_version(rest)
  defp check_version(_), do: {:error, "No supported version in VER"}

  defp check_type(type) do
    if type == <<0, 0, 0, 0>>, do: :ok, else: {:error, "TYPE missing or not a request"}
  end

  defp check_srv(nil), do: :ok

  defp check_srv(srv) do
    if srv == Roughtime.CertBox.lt_pubkey_hash(),
      do: :ok,
      else: {:error, "SRV does not match the long-term key"}
  end

  defp check_nonce(nonce) do
    if is_binary(nonce) and byte_size(nonce) == 32,
      do: :ok,
      else: {:error, "NONC missing or not 32 bytes"}
  end

  # Response should either be the same size as the request, or smaller,
  # to prevent amplification.
  defp check_size(res, request) do
    if byte_size(res) <= byte_size(request),
      do: :ok,
      else: {:error, "Response is larger than request"}
  end

  @doc """
  Sign a batch of `{request, nonce}` pairs with one signature. Returns one encoded
  response per request, in the same order.
  """
  @spec sign([{binary(), binary()}, ...]) :: [binary()]
  def sign(batch) do
    {root, paths} = Roughtime.MerkleTree.build(for {request, _nonce} <- batch, do: request)

    srep =
      Roughtime.Wire.generate_message(%{
        VER: @supported_version,
        RADI: @default_precision,
        MIDP: DateTime.now!("Etc/UTC"),
        VERS: @supported_version,
        ROOT: root
      })

    {sig, cert} = Roughtime.CertBox.sign(srep)

    for {{{_request, nonce}, path}, index} <- Enum.with_index(Enum.zip(batch, paths)) do
      Roughtime.Wire.generate(%{
        SIG: sig,
        NONC: nonce,
        TYPE: Roughtime.Wire.response_type(),
        PATH: path,
        SREP: srep,
        CERT: cert,
        INDX: <<index::unsigned-little-integer-size(32)>>
      })
    end
  end
end
