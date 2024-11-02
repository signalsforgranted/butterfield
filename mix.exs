defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      name: "Butterfield",
      app: :butterfield,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_options: [
        warnings_as_errors: true
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Roughtime.Application, []}
    ]
  end

  defp deps do
    [
      # Application
      {:libdecaf, "~> 2.1.1"},
      {:merkle_tree, "~> 2.0"},
      {:observer_cli, "1.8.0"},

      # Development
      {:dialyxir, "~> 1.3.0", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:sbom, "~> 0.6", only: :dev, runtime: false},
      {:ex_doc, "~> 0.30.3", only: [:dev], runtime: false},
      {:incendium, "~> 0.4.0", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp docs do
    [
      formatters: ["html"],
      main: "readme",
      extras: [
        "README.md",
        "notes/implementation.md",
      ]
    ]
  end
end
