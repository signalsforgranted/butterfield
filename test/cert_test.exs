defmodule Roughtime.CertBoxTest do
  use ExUnit.Case, async: true
  doctest Roughtime.CertBox

  @moduletag :capture_log

  setup do
    {pubkey, prikey} = :crypto.generate_key(:eddsa, :ed25519)

    {:ok, box} =
      Roughtime.CertBox.start_link(%{
        lt_prikey: Base.encode64(prikey),
        lt_pubkey: Base.encode64(pubkey),
        cert_duration: 2
      })

    %{box: box, lt_prikey: prikey, lt_pubkey: pubkey}
  end

  test "generates temporary long-term key" do
    pubkey = Roughtime.CertBox.pubkey()
    assert pubkey != nil
  end

  test "generates hash of long-term public key" do
    pubkey_hash = Roughtime.CertBox.lt_pubkey_hash()
    assert byte_size(pubkey_hash) == 32
  end

  test "generates new keys and valid certificate with signature", context do
    cert = Roughtime.CertBox.cert()
    assert cert != nil

    pubkey = Roughtime.CertBox.pubkey()
    assert byte_size(pubkey) == 32

    cert = Roughtime.Wire.parse_message(cert, false)

    assert :crypto.verify(
             :eddsa,
             :none,
             Roughtime.CertBox.delegation_context() <> Map.fetch!(cert, :DELE),
             Map.fetch!(cert, :SIG),
             [Map.fetch!(context, :lt_pubkey), :ed25519]
           )
  end

  test "can sign a response with temporary keys", _context do
    pubkey = Roughtime.CertBox.pubkey()
    payload = <<"test string">>
    {sig, cert} = Roughtime.CertBox.sign(payload)
    assert cert == Roughtime.CertBox.cert()

    assert :crypto.verify(
             :eddsa,
             :none,
             Roughtime.CertBox.response_context() <> payload,
             sig,
             [pubkey, :ed25519]
           )
  end

  test "certificate is backdated by an hour and lasts cert_duration", _context do
    dele = Roughtime.Wire.parse_message(Roughtime.CertBox.cert()) |> Map.fetch!(:DELE)
    now = DateTime.utc_now()

    assert DateTime.diff(dele[:MAXT], dele[:MINT], :hour) == 3
    assert DateTime.compare(dele[:MINT], now) == :lt
    assert DateTime.compare(dele[:MAXT], now) == :gt
  end

  test "rotates to a new temporary key and certificate", context do
    old = {Roughtime.CertBox.pubkey(), Roughtime.CertBox.cert()}
    send(Roughtime.CertBox, :rotate)
    {pubkey, cert} = {Roughtime.CertBox.pubkey(), Roughtime.CertBox.cert()}

    assert {pubkey, cert} != old

    cert = Roughtime.Wire.parse_message(cert, false)

    assert :crypto.verify(
             :eddsa,
             :none,
             Roughtime.CertBox.delegation_context() <> Map.fetch!(cert, :DELE),
             Map.fetch!(cert, :SIG),
             [Map.fetch!(context, :lt_pubkey), :ed25519]
           )
  end

  test "keeps private keys out of its status", context do
    refute inspect(:sys.get_status(Roughtime.CertBox), limit: :infinity) =~
             inspect(context.lt_prikey, limit: :infinity)
  end
end
