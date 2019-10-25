defmodule Loner.MixProject do
  use Mix.Project

  def project do
    [
      app: :loner,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        test: "test --no-start" # Required for LocalCluster
      ]
    ]

  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Loner.Application, []}
    ]
  end

  defp deps do
    [
      {:horde, "~> 0.7"},
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false},
      {:local_cluster, "~> 1.0.4", only: :test, runtime: false},
      {:schism, "~> 1.0.1", only: :test, runtime: false}
    ]
  end
end
