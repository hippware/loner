defmodule Loner.Application do
  @moduledoc "Top level application module for Loner"

  def start(_, _) do
    Supervisor.start_link(
      [
        {DynamicSupervisor, [name: ConflictListenerSupervisor, strategy: :one_for_one]},
        {Horde.Registry, [name: Loner.registry(), keys: :unique]},
        {Horde.DynamicSupervisor,
         [name: Loner.supervisor(), strategy: :one_for_one]},
        Loner.NodeMonitor
      ],
      strategy: :one_for_one,
      name: Loner.Supervisor
    )
  end
end
