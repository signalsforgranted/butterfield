defmodule Roughtime.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    lt_prikey = Application.get_env(:butterfield, :private_key)
    lt_pubkey = Application.get_env(:butterfield, :public_key)
    cert_duration = Application.get_env(:butterfield, :cert_duration)

    Application.delete_env(:butterfield, :private_key)
    Application.delete_env(:butterfield, :public_key)

    children = [
      {Roughtime.CertBox,
       %{
         lt_prikey: lt_prikey,
         lt_pubkey: lt_pubkey,
         cert_duration: cert_duration
       }},
      Roughtime.Handler,
      Roughtime.Server
    ]

    opts = [strategy: :one_for_one, name: Roughtime.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
