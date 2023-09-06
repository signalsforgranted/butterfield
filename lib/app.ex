defmodule Roughtime.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Roughtime.CertBox,
      Roughtime.Handler
    ]

    opts = [strategy: :one_for_one, name: Roughtime.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
