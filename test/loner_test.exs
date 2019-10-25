defmodule LonerTest do
  use ExUnit.Case
  doctest Loner

  describe "5 node cluster" do
    setup do
      nodes = LocalCluster.start_nodes("loner-cluster", 5)
      {:ok, nodes: nodes, all_nodes: [node() | nodes]}
    end

    test "All supervisors start up", ctx do
      assert Horde.Cluster.members(Loner.DynamicSupervisor) |> Enum.sort()
      == (for n <- ctx.all_nodes, do: {Loner.DynamicSupervisor, n}) |> Enum.sort()
    end

    test "All registries should start up", ctx do
      assert Horde.Cluster.members(Loner.Registry) |> Enum.sort()
      == (for n <- ctx.all_nodes, do: {Loner.Registry, n}) |> Enum.sort()
    end

    test "Test server should start up" do
      assert {:ok, pid} = Loner.start(Singleton, TestServer)

      assert TestServer.is_test?(pid)
      assert TestServer.is_test?(Singleton)
    end
  end
end

defmodule TestServer do
  use GenServer
  def start_link(name), do: GenServer.start_link(__MODULE__, name: name)

  def init(_), do: {:ok, nil}

  def exit(p, reason \\ :normal), do: GenServer.call(p, {:exit, reason})

  def is_test?(p), do: GenServer.call(p, :is_test)

  def handle_call({:exit, reason}, _from, s), do: {:stop, reason, :ok, s}

  def handle_call(:is_test, _from, s), do: {:reply, true, s}
end
