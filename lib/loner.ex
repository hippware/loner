defmodule Loner do
  @moduledoc """
  A system for starting and supervising a cluster-wide singleton process
  using Horde.
  """

  @type child_spec() :: module() | {module(), term()} | module()

  @registry Loner.Registry
  @supervisor Loner.DynamicSupervisor

  def name(name), do: {:via, Horde.Registry, {@registry, name}}

  def start(module, name) do
    Horde.DynamicSupervisor.start_child(@supervisor, {module, name: name(name)})
  end

  def stop(name) do
    Horde.DynamicSupervisor.which_children(@supervisor)

    case whereis_name(name) do
      :undefined ->
        :ok

      pid when is_pid(pid) ->
        Horde.DynamicSupervisor.terminate_child(@supervisor, pid)
    end
  end

  def whereis_name(name), do: Horde.Registry.whereis_name({@registry, name})
end
