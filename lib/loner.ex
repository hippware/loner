defmodule Loner do
  @moduledoc """
  A system for starting and supervising a cluster-wide singleton process
  using Horde.
  """

  alias Loner.ConflictListener

  @type child_spec() :: module() | {module(), term()} | module()
  @type name() :: {:via, module(), {module(), atom()}}

  @registry Loner.Registry
  @supervisor Loner.DynamicSupervisor

  @spec name(atom()) :: name()
  def name(name), do: {:via, Horde.Registry, {@registry, name}}

  @spec start(Supervisor.child_spec() | module() | {module(), term()}) ::
          DynamicSupervisor.on_start_child()
  def start(child_spec) do
    full_child_spec = Supervisor.child_spec(child_spec, [])
    type = Map.get(full_child_spec, :type, :worker)

    case type do
      :worker ->
        start_worker(full_child_spec)

      :supervisor ->
        start_supervisor(full_child_spec)
    end
  end

  @spec stop(atom() | pid()) :: :ok
  def stop(pid) when is_pid(pid) do
    Horde.DynamicSupervisor.terminate_child(@supervisor, pid)
  end

  def stop(name) do
    case whereis_name(name) do
      nil -> :ok
      pid when is_pid(pid) -> stop(pid)
    end
  end

  def registry, do: @registry
  def supervisor, do: @supervisor

  @spec whereis_name(atom()) :: pid() | nil
  def whereis_name(name) do
    case Horde.Registry.whereis_name({@registry, name}) do
      :undefined -> nil
      val -> val
    end
  end

  defp start_worker(child_spec) do
    Horde.DynamicSupervisor.start_child(@supervisor, child_spec)
  end

  defp start_supervisor(child_spec) do
    with {:ok, pid} <-
           Horde.DynamicSupervisor.start_child(@supervisor, child_spec),
      {:ok, _listener_pid} = DynamicSupervisor.start_child(
        ConflictListenerSupervisor,
        {ConflictListener, {child_spec.id, pid}}
      ) do
      {:ok, pid}
    end
  end
end
