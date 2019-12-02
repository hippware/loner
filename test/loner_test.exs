defmodule LonerTest do
  use ExUnit.Case
  import Eventually
  doctest Loner

  setup do
    Application.stop(:loner)
    nodes = LocalCluster.start_nodes("loner-cluster", 4)

    :rpc.multicall(nodes, Application, :put_env, [
      :loner,
      :horde_opts,
      [delta_crdt_options: [sync_interval: 5]]
    ])

    :rpc.multicall(nodes, Application, :ensure_all_started, [:loner])

    on_exit(fn ->
      :rpc.multicall(nodes, Application, :stop, [:loner])
    end)

    {:ok, nodes: nodes}
  end

  describe "basic startup" do
    test "All supervisors start up", ctx do
      assert_eventually(
        ctx
        |> call_one_remote(Horde.Cluster, :members, [Loner.DynamicSupervisor])
        |> Enum.sort() ==
          for(n <- [node() | ctx.nodes], do: {Loner.DynamicSupervisor, n}) |> Enum.sort()
      )
    end

    test "All registries should start up", ctx do
      assert_eventually(
        ctx
        |> call_one_remote(Horde.Cluster, :members, [Loner.Registry])
        |> Enum.sort() ==
          for(n <- [node() | ctx.nodes], do: {Loner.Registry, n}) |> Enum.sort()
      )
    end
  end

  describe "simple singleton server" do
    test "TestServer should be findable from all nodes", ctx do
      start_server(ctx)

      assert_all_nodes(ctx, TestServer, :is_test?, [Loner.name(TestServer)])
    end

    test "TestServer should be restarted on abnormal exit", ctx do
      pid = start_server(ctx)

      assert_all_nodes(
        ctx,
        DynamicSupervisor,
        :which_children,
        [Loner.DynamicSupervisor],
        fn x -> is_list(x) and x != [] end
      )

      Process.exit(pid, :kill)

      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], &is_pid/1)

      pid2 = call_one_remote(ctx, Loner, :whereis_name, [TestServer])
      assert is_pid(pid2)
      assert pid != pid2

      assert_all_nodes(ctx, TestServer, :is_test?, [Loner.name(TestServer)])
    end

    test "adding an extra node should make the singleton avaialble to it",
         ctx do
      start_server(ctx)

      [n] = LocalCluster.start_nodes("loner-cluster2", 1)
      {:ok, _} = :rpc.call(n, Application, :ensure_all_started, [:loner])

      assert_eventually(
        :rpc.call(n, TestServer, :is_test?, [Loner.name(TestServer)]) == true
      )
    end

    test """
         removing the node running the singleton should cause it to restart elsewhere
         """,
         ctx do
      pid = start_server(ctx)
      node = node(pid)

      # Let the cluster sync up
      Process.sleep(500)

      # Stop the node running the test server
      LocalCluster.stop_nodes([node])

      ctx = update_in(ctx.nodes, &(&1 -- [node]))

      # It should eventually restart
      assert_all_nodes(
        ctx,
        DynamicSupervisor,
        :which_children,
        [Loner.DynamicSupervisor],
        fn x -> x != [] end
      )

      # and be registered
      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], &is_pid/1)

      pid2 = call_one_remote(ctx, Loner, :whereis_name, [TestServer])

      # and be the right process
      assert TestServer.is_test?(pid2)
      assert_all_nodes(ctx, TestServer, :is_test?, [Loner.name(TestServer)])
      assert pid != pid2
    end

    test "stop/1 with a pid should stop the singleton", ctx do
      pid = start_server(ctx)

      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], &is_pid/1)

      assert_eventually(:ok == call_one_remote(ctx, Loner, :stop, [pid]))
      refute_eventually(:rpc.call(node(pid), Process, :alive?, [pid]))

      assert_all_nodes(
        ctx,
        DynamicSupervisor,
        :which_children,
        [Loner.DynamicSupervisor],
        fn x -> x == [] end
      )

      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], fn x ->
        x == nil
      end)
    end

    test "stop/1 with a name should stop the singleton", ctx do
      pid = start_server(ctx)

      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], &is_pid/1)

      assert_eventually(:ok == call_one_remote(ctx, Loner, :stop, [TestServer]))
      refute_eventually(:rpc.call(node(pid), Process, :alive?, [pid]))

      assert_all_nodes(
        ctx,
        DynamicSupervisor,
        :which_children,
        [Loner.DynamicSupervisor],
        fn x -> x == [] end
      )

      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], fn x ->
        x == nil
      end)
    end

    test "stop/1 with an invalid name should return :ok", ctx do
      assert :ok == call_one_remote(ctx, Loner, :stop, [Fnord])
    end

    test "should tidy up multiple servers after netsplit", ctx do
      [n1, n2, n3, n4] = ctx.nodes
      g1 = [n1, n2]
      g2 = [n3, n4]
      Schism.partition(g1)
      Schism.partition(g2)

      Enum.each(ctx.nodes, &Node.spawn(&1, Loner, :start, [TestServer]))

      # There should be one instance on each
      assert_all_nodes(ctx, Loner, :whereis_name, [TestServer], &is_pid/1)
      assert_all_nodes(
        ctx,
        DynamicSupervisor,
        :which_children,
        [Loner.DynamicSupervisor],
        fn x -> x != [] end
      )

      pid1 = :rpc.call(n1, Loner, :whereis_name, [TestServer])
      pid2 = :rpc.call(n4, Loner, :whereis_name, [TestServer])

      assert pid1 != pid2

      Schism.heal(ctx.nodes)

      assert_eventually(
        (
          pids =
            Enum.map(
              ctx.nodes,
              &:rpc.call(&1, Loner, :whereis_name, [TestServer])
            )

          Enum.all?(pids, &is_pid/1) and pids |> Enum.uniq() |> length() == 1
        )
      )
    end
  end

  describe "Supervised supervisor" do
    test "Should only start up one instance of the supervised server", ctx do
      :rpc.multicall(ctx.nodes, Loner, :start, [TestSupervisor])

      assert_all_nodes(ctx, Loner, :whereis_name, [TestSupervisor], &is_pid/1)

      assert_eventually(length(find_registered_servers(ctx.nodes)) == 1)
    end

    test "Should tidy up multiple supervisors once a netsplit is healed", ctx do
      [n1, n2, n3, n4] = ctx.nodes
      g1 = [n1, n2]
      g2 = [n3, n4]
      Schism.partition(g1)
      Schism.partition(g2)

      Enum.each(ctx.nodes, &Node.spawn(&1, Loner, :start, [TestSupervisor]))

      # There should be one instance on each partition
      assert_all_nodes(ctx, Loner, :whereis_name, [TestSupervisor], &is_pid/1)

      {[p1, p1, p2, p2], []} =
        :rpc.multicall(ctx.nodes, Loner, :whereis_name, [TestSupervisor])

      assert p1 != p2

      IO.inspect node(p1)
      IO.inspect node(p2)

      [rs1] = find_registered_servers(g1)
      [rs2] = find_registered_servers(g2)
      assert rs1 != rs2

      Schism.heal(ctx.nodes)

      assert_eventually(
        find_registered_servers(ctx.nodes) |> Enum.uniq() |> length() == 1
      )
      assert_all_nodes_p(ctx, Loner, :whereis_name, [TestSupervisor], &is_pid/1)

      assert_eventually(
        (
          pids =
            Enum.map(
              ctx.nodes,
              &:rpc.call(&1, Loner, :whereis_name, [TestSupervisor])
            ) |> IO.inspect

          Enum.all?(pids, &is_pid/1) and pids |> Enum.uniq() |> length() == 1
        )
      )
    end
  end

  defp start_server(ctx) do
    {:ok, pid} = call_one_remote(ctx, Loner, :start, [TestServer])
    pid
  end

  defp assert_all_nodes(ctx, m, f, a, check_fun \\ fn x -> x == true end, timeout \\ 1000) do
    for n <- ctx.nodes do
      assert_eventually(check_fun.(:rpc.call(n, m, f, a)), timeout)
    end
  end

  defp assert_all_nodes_p(ctx, m, f, a, check_fun \\ fn x -> x == true end, timeout \\ 1000) do
    for n <- ctx.nodes do
      IO.inspect n
      assert_eventually(check_fun.(:rpc.call(n, m, f, a) |> IO.inspect), timeout)
    end
  end

  def call_one_remote(ctx, m, f, a) do
    ctx.nodes
    |> Enum.random()
    |> :rpc.call(m, f, a)
  end

  defp find_registered_servers(nodes) do
    nodes
    |> :rpc.multicall(Process, :whereis, [RegisteredServer])
    |> elem(0)
    |> Enum.filter(&is_pid/1)
  end
end
