defmodule Charlie.MixProject do
  use Mix.Project

  def project do
    [
      app: :charlie,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Charlie.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, github: "Kraigie/nostrum"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.7"},
      {:req, "~> 0.5.8"},
      {:vix, "~> 0.33.0"}
    ]
  end
end
