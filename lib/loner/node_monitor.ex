defmodule Loner.NodeMonitor do
  use GenServer

  alias Horde.Cluster

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ok = :net_kernel.monitor_nodes(true)
    update_nodes()
    {:ok, nil}
  end

  def handle_info({:nodeup, _node}, s) do
    update_nodes()
    {:noreply, s}
  end

  def handle_info({:nodedown, _node}, s) do
    update_nodes()
    {:noreply, s}
  end

  def handle_info(_, s) do
    {:noreply, s}
  end

  defp update_nodes() do
    nodes = Node.list([:visible, :this])

    registries = for n <- nodes, do: {Loner.Registry, n}
    Cluster.set_members(Loner.Registry, registries)

    supervisors = for n <- nodes, do: {Loner.DynamicSupervisor, n}
    Cluster.set_members(Loner.DynamicSupervisor, supervisors)
  end
end
