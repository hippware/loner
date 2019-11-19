defmodule Loner do
  @moduledoc """
  A system for starting and supervising a cluster-wide singleton process
  using Horde.
  """

  @type child_spec() :: module() | {module(), term()} | module()
  @type name() :: {:via, module(), {module(), atom()}}

  @registry Loner.Registry
  @supervisor Loner.DynamicSupervisor

  @spec name(atom()) :: name()
  def name(name), do: {:via, Horde.Registry, {@registry, name}}

  @spec start(module(), term()) :: DynamicSupervisor.on_start_child()
  def start(module, init_args \\ []) do
    Horde.DynamicSupervisor.start_child(@supervisor, {module, init_args})
  end

  @spec stop(atom() | pid()) :: :ok
  def stop(pid) when is_pid(pid) do
    Horde.DynamicSupervisor.terminate_child(@supervisor, pid)
  end

  def stop(name) do
    case whereis_name(name) do
      :undefined -> :ok
      pid when is_pid(pid) -> stop(pid)
    end
  end

  @spec whereis_name(atom()) :: pid() | :undefined
  def whereis_name(name), do: Horde.Registry.whereis_name({@registry, name})
end
