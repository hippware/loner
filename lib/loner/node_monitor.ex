defmodule Loner.NodeMonitor do
  @moduledoc """
  GenServer responsible for monitoring node additions/deletions and triggering
  updates to the Horde node list to ensure it stays current
  """

  use GenServer

  alias Horde.Cluster

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
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

  defp update_nodes do
    nodes = Node.list([:visible, :this])

    registries = for n <- nodes, do: {Loner.Registry, n}
    :ok = Cluster.set_members(Loner.Registry, registries)

    supervisors = for n <- nodes, do: {Loner.DynamicSupervisor, n}
    :ok = Cluster.set_members(Loner.DynamicSupervisor, supervisors)
  end
end
