defmodule Loner.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :loner,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      source_url: "https://github.com/hippware/loner",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      aliases: aliases(),
      dialyzer: [
        flags: [
          :error_handling,
          :race_conditions,
          :underspecs,
          :unknown,
          :unmatched_returns
        ]
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
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 0.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:eventually, "~> 1.1", only: :test, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
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

  defp aliases() do
    [
      # Required for LocalCluster
      test: "test --no-start"
    ]
  end

  defp description do
    """
    Loner provides a simple method for creating a registered, supervised
    singleton process within a multi-node cluster with the help of Horde.
    """
  end

  defp package do
    [
      maintainers: ["Bernard Duggan"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/hippware/loner"}
    ]
  end

  defp docs do
    [
      source_ref: "v#\{@version\}",
      main: "readme",
      extras: ["README.md"],
    ]
  end
end
