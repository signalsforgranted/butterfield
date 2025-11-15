defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      name: "Butterfield",
      app: :butterfield,
      version: "0.8.0",
      elixir: "~> 1.19",
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
      extra_applications: [:logger, :public_key, :crypto],
      mod: {Roughtime.Application, []}
    ]
  end

  defp deps do
    [
      # Application
      {:merkle_tree, "~> 2.0"},
      {:observer_cli, "1.8.0"},

      # Development
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7.13", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14.1", only: [:dev, :test], runtime: false},
      {:sbom, "~> 0.7", only: :dev, runtime: false},
      {:ex_doc, "~> 0.39.1", only: [:dev], runtime: false},
      {:incendium, "~> 0.5.0", only: [:dev], runtime: false}
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
        "README.md"
      ]
    ]
  end
end
