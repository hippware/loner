defmodule Loner.Application do
  @moduledoc "Top level application module for Loner"

  def start(_, _) do
    horde_opts = Application.get_env(:loner, :horde_opts, [])

    Supervisor.start_link(
      [
        {DynamicSupervisor,
         [name: ConflictListenerSupervisor, strategy: :one_for_one]},
        {Horde.Registry, [name: Loner.registry(), keys: :unique] ++ horde_opts},
        {Horde.DynamicSupervisor,
         [name: Loner.supervisor(), strategy: :one_for_one] ++ horde_opts},
        Loner.NodeMonitor
      ],
      strategy: :one_for_one,
      name: Loner.Supervisor
    )
  end
end
