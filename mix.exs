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
        # Required for LocalCluster
        test: "test --no-start"
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
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:eventually, "~> 1.1", only: :test, runtime: false},
      # TODO: Back to upstream once logger config fix is merged
      # (https://github.com/whitfin/local-cluster/pull/12)
      # {:local_cluster, "~> 1.0.4", only: :test, runtime: false},
      {:local_cluster,
       github: "hippware/local-cluster",
       branch: "fix-remote-log-level",
       only: :test,
       runtime: false}
    ]
  end
end
