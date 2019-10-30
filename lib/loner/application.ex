defmodule Loner.Application do
  def start(_, _) do
    Supervisor.start_link(
      [
        {Horde.Registry, [name: Loner.Registry, keys: :unique]},
        {Horde.DynamicSupervisor, [name: Loner.DynamicSupervisor, strategy: :one_for_one]},
        {Loner.NodeMonitor, []}
      ],
      strategy: :one_for_one,
      name: Loner.Supervisor
    )
  end
end
