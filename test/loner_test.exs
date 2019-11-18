defmodule LonerTest do
  use ExUnit.Case
  import Eventually
  doctest Loner

  @nodes 5

  setup do
    nodes = LocalCluster.start_nodes("loner-cluster", @nodes - 1)
    all_nodes = [node() | nodes]

    :rpc.multicall(Application, :ensure_all_started, [:loner])

    on_exit(fn ->
      :rpc.multicall(Application, :stop, [:loner])
    end)

    {:ok, nodes: nodes, all_nodes: all_nodes}
  end

  test "All supervisors start up", ctx do
    assert_eventually(
      Loner.DynamicSupervisor |> Horde.Cluster.members() |> Enum.sort() ==
        for(n <- ctx.all_nodes, do: {Loner.DynamicSupervisor, n}) |> Enum.sort()
    )
  end

  test "All registries should start up", ctx do
    assert Loner.Registry |> Horde.Cluster.members() |> Enum.sort() ==
             for(n <- ctx.all_nodes, do: {Loner.Registry, n}) |> Enum.sort()
  end

  test "Singleton should start up and be findable" do
    assert {:ok, pid} = Loner.start(TestServer, Singleton)

    assert_eventually(Loner.whereis_name(Singleton) == pid)
    assert TestServer.is_test?(pid)
    assert TestServer.is_test?(Loner.name(Singleton))
  end

  test "Singleton should be findable from all nodes", ctx do
    assert {:ok, pid} = Loner.start(TestServer, Singleton)

    for n <- ctx.all_nodes do
      assert_eventually(
        :rpc.call(n, TestServer, :is_test?, [Loner.name(Singleton)]) == true
      )
    end
  end

  test "Singleton should be restarted on abnormal exit", ctx do
    assert {:ok, pid} = Loner.start(TestServer, Singleton)

    assert_eventually(
      DynamicSupervisor.which_children(Loner.DynamicSupervisor) != []
    )

    Process.exit(pid, :kill)

    assert_eventually(is_pid(Loner.whereis_name(Singleton)))
    pid2 = Loner.whereis_name(Singleton)

    assert is_pid(pid2)
    assert TestServer.is_test?(Loner.name(Singleton))
    assert pid != pid2

    for n <- ctx.nodes do
      assert_eventually(
        :rpc.call(n, TestServer, :is_test?, [Loner.name(Singleton)]) == true
      )
    end
  end

  test "adding an extra node should make the singleton avaialble to it" do
    assert {:ok, pid} = Loner.start(TestServer, Singleton)

    [n] = LocalCluster.start_nodes("loner-cluster2", 1)

    assert_eventually(
      :rpc.call(n, TestServer, :is_test?, [Loner.name(Singleton)]) == true
    )
  end

  test """
  removing the node running the singleton should cause it to restart elsewhere
  """ do
    {:ok, pid!} = Loner.start(TestServer, Singleton)
    pid! = restart_until_remote(pid!)
    assert_eventually(Loner.whereis_name(Singleton) == pid!)

    # Let the cluster sync up
    Process.sleep(500)

    # Stop the node running the test server
    LocalCluster.stop_nodes([:erlang.node(pid!)])

    # It should eventually restart
    assert_eventually(
      DynamicSupervisor.which_children(Loner.DynamicSupervisor) != []
    )

    # and be registered
    assert_eventually(is_pid(Loner.whereis_name(Singleton)))
    pid2 = Loner.whereis_name(Singleton)

    # and be the right process
    assert TestServer.is_test?(pid2)
    assert TestServer.is_test?(Loner.name(Singleton))
    assert pid! != pid2
  end

  defp restart_until_remote(pid) do
    if :erlang.node(pid) == node() do
      Process.exit(pid, :kill)
      assert_eventually([] != Horde.Registry.whereis(Loner.name(Singleton)))
      [{new_pid, _}] = Horde.Registry.whereis(Loner.name(Singleton))
      restart_until_remote(new_pid)
    else
      pid
    end
  end
end
