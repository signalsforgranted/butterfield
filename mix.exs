defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      app: :butterfield,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_options: [
        warnings_as_errors: true
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :asn1, :public_key],
      mod: {Roughtime.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.3.0", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30.3", only: [:dev], runtime: false},
      {:incendium, "~> 0.4.0", only: [:dev]}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
