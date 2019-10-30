defmodule Loner do
  @moduledoc """
  A system for starting and supervising a cluster-wide singleton process
  using Horde.
  """

  alias Horde.DynamicSupervisor
  alias Horde.Registry

  @type child_spec() :: module() | module() | [term()]

  @registry Loner.Registry
  @supervisor Loner.DynamicSupervisor

  def name(name), do: {:via, Registry, {@registry, name}}

  def start(module, name) do
    DynamicSupervisor.start_child(@supervisor, {module, name})
  end

  def stop(name) do
    DynamicSupervisor.which_children(@supervisor) |> IO.inspect()

    case Registry.whereis(name) do
      [] ->
        :ok

      [{pid, _}] ->
        DynamicSupervisor.terminate_child(@supervisor, pid)
    end
  end
end
