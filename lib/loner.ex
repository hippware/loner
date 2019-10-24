defmodule Loner do
  @moduledoc """
  Documentation for Loner.
  """

  @type child_spec() :: Supervisor.child_spec() | {module(), term()} | module() | [term()]

  @spec start(term(), Supervisor.child_spec()) :: Supervisor.start_child()
  def start(name, child_spec) do
    case Horde.Registry.lookup(Loner.Registry, name) do
      [] -> start_new(name, child_spec)
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp start_new(name, child_spec) do
    case Horde.DynamicSupervisor.start_child(Loner.DynamicSupervisor, child_spec) do
      :ignore -> :ignore
      {:ok, pid} -> register(name, pid)
      {:ok, pid, _info} -> register(name, pid)
      {:error, e} -> {:error, e}
    end
  end

  defp register(name, pid) do
    case Horde.Registry.register(Loner.Registry, name, pid) do
      {:ok, _} -> {:ok, pid}
      {:error, {:already_registered, other_pid}} -> {:ok, other_pid}
    end
  end
end
