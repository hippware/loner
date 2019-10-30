defmodule LonerTest do
  use ExUnit.Case
  import Eventually
  doctest Loner

  @nodes 5

  setup_all do
    nodes = LocalCluster.start_nodes("loner-cluster", @nodes - 1)
    all_nodes = [node() | nodes]

    {:ok, nodes: nodes, all_nodes: all_nodes}
  end

  setup do
    :rpc.multicall(Application, :ensure_all_started, [:loner])

    on_exit(fn ->
      :rpc.multicall(Application, :stop, [:loner])
    end)

    :ok
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
    assert_eventually(DynamicSupervisor.which_children(Loner.DynamicSupervisor) != [])

    assert_eventually(Horde.Registry.whereis(Loner.name(Singleton)) == [{pid, nil}])
    assert TestServer.is_test?(pid)
    assert TestServer.is_test?(Loner.name(Singleton))
  end

  test "Singleton should be findable from all nodes", ctx do
    assert {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))
    assert_eventually(DynamicSupervisor.which_children(Loner.DynamicSupervisor) != [])

    for n <- ctx.all_nodes do
      assert true == :rpc.call(n, TestUtils, :test_exists?, [Singleton, pid])
    end
  end

  test "Singleton should be restarted on abnormal exit", ctx do
    assert {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))
    assert_eventually(DynamicSupervisor.which_children(Loner.DynamicSupervisor) != [])

    Process.exit(pid, :kill)

    assert_eventually([] != Horde.Registry.whereis(Loner.name(Singleton)))
    [{pid2, _}] = Horde.Registry.whereis(Loner.name(Singleton))
    assert TestServer.is_test?(Loner.name(Singleton))
    assert pid != pid2

    for n <- ctx.nodes do
      assert true == :rpc.call(n, TestUtils, :test_exists?, [Singleton, pid2])
    end
  end

  test "adding an extra node should make the singleton avaialble to it" do
    assert {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))

    [n] = LocalCluster.start_nodes("loner-cluster2", 1)

    assert_eventually(true == :rpc.call(n, TestUtils, :test_exists?, [Singleton, pid]))
  end

  test """
       explicitly removing the node running the singleton should cause it to restart
       elsewhere
       """,
       ctx do
    {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))
    pid = restart_until_remote(pid)
    DynamicSupervisor.which_children(Loner.DynamicSupervisor) |> IO.inspect()
    :sys.get_status(Loner.DynamicSupervisor)

    # LocalCluster.stop_nodes([:erlang.node(pid)])
    s = for n <- ctx.all_nodes -- [:erlang.node(pid)], do: {Loner.DynamicSupervisor, n}
    Horde.Cluster.set_members(Loner.DynamicSupervisor, s)

    DynamicSupervisor.which_children(Loner.DynamicSupervisor) |> IO.inspect()
    [{pid2, nil}] = assert_eventually(Horde.Registry.whereis(Loner.name(Singleton)) != [])
    assert TestServer.is_test?(pid2)
    assert TestServer.is_test?(Loner.name(Singleton))
    assert pid != pid2
  end

  test """
       removing the node running the singleton should cause it to restart elsewhere
       """,
       ctx do
    {:ok, pid} = Loner.start(TestServer, Loner.name(Singleton))
    pid = restart_until_remote(pid)
    IO.inspect(pid)
    IO.inspect(:erlang.node(pid))
    DynamicSupervisor.which_children(Loner.DynamicSupervisor) |> IO.inspect()
    :sys.get_status(Loner.DynamicSupervisor)

    LocalCluster.stop_nodes([:erlang.node(pid)])

    DynamicSupervisor.which_children(Loner.DynamicSupervisor) |> IO.inspect()
    :sys.get_status(Loner.DynamicSupervisor)
    [{pid2, nil}] = assert_eventually(Horde.Registry.whereis(Loner.name(Singleton)) != [])
    assert TestServer.is_test?(pid2)
    assert TestServer.is_test?(Loner.name(Singleton))
    assert pid != pid2
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
