defmodule LonerTest do
  use ExUnit.Case
  import Eventually
  doctest Loner

  describe "5 node cluster" do
    setup do
      nodes = LocalCluster.start_nodes("loner-cluster", 5)
      {:ok, nodes: nodes, all_nodes: [node() | nodes]}
    end

    test "All supervisors start up", ctx do
      assert Horde.Cluster.members(Loner.DynamicSupervisor) |> Enum.sort() ==
               for(n <- ctx.all_nodes, do: {Loner.DynamicSupervisor, n}) |> Enum.sort()
    end

    test "All registries should start up", ctx do
      assert Horde.Cluster.members(Loner.Registry) |> Enum.sort() ==
               for(n <- ctx.all_nodes, do: {Loner.Registry, n}) |> Enum.sort()
    end

    test "Singleton should start up and be findable" do
      assert {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))

      assert_eventually Horde.Registry.lookup(Loner.Registry, Singleton) == [{pid, nil}]
      assert TestServer.is_test?(pid)
      assert TestServer.is_test?(Loner.name(Singleton))
    end

    test "Singleton should be findable from all nodes", ctx do
      assert {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))
      root = self()

      pids = for n <- ctx.nodes, do: Node.spawn(n, fn ->
        assert_eventually Horde.Registry.lookup(Loner.Registry, Singleton)
        send(root, {self(), :ok})
      end)

      for p <- pids, do: assert_receive {p, :ok}
    end

    test "Singleton should be restarted on death" do
    end

    test "Singleton should be duplicated on netsplit" do
    end

    test "Singleton should be de-duplicated on split recovery" do
    end
  end
end
