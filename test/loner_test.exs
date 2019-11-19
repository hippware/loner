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

  test "TestServer should start up and be findable" do
    assert {:ok, pid} = Loner.start(TestServer)

    assert_eventually(Loner.whereis_name(TestServer) == pid)
    assert TestServer.is_test?(pid)
    assert TestServer.is_test?(Loner.name(TestServer))
  end

  test "TestServer should be findable from all nodes", ctx do
    assert {:ok, pid} = Loner.start(TestServer)

    for n <- ctx.all_nodes do
      assert_eventually(
        :rpc.call(n, TestServer, :is_test?, [Loner.name(TestServer)]) == true
      )
    end
  end

  test "TestServer should be restarted on abnormal exit", ctx do
    assert {:ok, pid} = Loner.start(TestServer)

    assert_eventually(
      DynamicSupervisor.which_children(Loner.DynamicSupervisor) != []
    )

    Process.exit(pid, :kill)

    assert_eventually(is_pid(Loner.whereis_name(TestServer)))
    pid2 = Loner.whereis_name(TestServer)

    assert is_pid(pid2)
    assert TestServer.is_test?(Loner.name(TestServer))
    assert pid != pid2

    for n <- ctx.nodes do
      assert_eventually(
        :rpc.call(n, TestServer, :is_test?, [Loner.name(TestServer)]) == true
      )
    end
  end

  test "adding an extra node should make the singleton avaialble to it" do
    assert {:ok, pid} = Loner.start(TestServer)

    [n] = LocalCluster.start_nodes("loner-cluster2", 1)

    assert_eventually(
      :rpc.call(n, TestServer, :is_test?, [Loner.name(TestServer)]) == true
    )
  end

  test """
  removing the node running the singleton should cause it to restart elsewhere
  """ do
    {:ok, pid!} = Loner.start(TestServer)
    pid! = restart_until_remote(pid!)
    assert_eventually(Loner.whereis_name(TestServer) == pid!)

    # Let the cluster sync up
    Process.sleep(500)

    # Stop the node running the test server
    LocalCluster.stop_nodes([:erlang.node(pid!)])

    # It should eventually restart
    assert_eventually(
      DynamicSupervisor.which_children(Loner.DynamicSupervisor) != []
    )

    # and be registered
    assert_eventually(is_pid(Loner.whereis_name(TestServer)))
    pid2 = Loner.whereis_name(TestServer)

    # and be the right process
    assert TestServer.is_test?(pid2)
    assert TestServer.is_test?(Loner.name(TestServer))
    assert pid! != pid2
  end

  test "stop/1 with a pid should stop the singleton" do
    {:ok, pid} = Loner.start(TestServer)
    assert :ok == Loner.stop(pid)
    refute Process.alive?(pid)

    assert_eventually(
      DynamicSupervisor.which_children(Loner.DynamicSupervisor) == []
    )

    assert_eventually(Loner.whereis_name(TestServer) == :undefined)
  end

  test "stop/1 with a name should stop the singleton" do
    {:ok, pid} = Loner.start(TestServer)
    assert :ok == Loner.stop(TestServer)
    refute Process.alive?(pid)

    assert_eventually(
      DynamicSupervisor.which_children(Loner.DynamicSupervisor) == []
    )

    assert_eventually(Loner.whereis_name(TestServer) == :undefined)
  end

  test "stop/1 with an invalid name should return :ok" do
    assert :ok == Loner.stop(Fnord)
  end

  defp restart_until_remote(pid) do
    if :erlang.node(pid) == node() do
      Process.exit(pid, :kill)
      assert_eventually(pid != Loner.whereis_name(TestServer))
      assert_eventually(:undefined != Loner.whereis_name(TestServer))
      new_pid = Loner.whereis_name(TestServer)
      restart_until_remote(new_pid)
    else
      pid
    end
  end
end
