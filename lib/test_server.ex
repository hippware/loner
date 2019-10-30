defmodule TestServer do
  @moduledoc """
  Simple test GenServer - must be provided as an .ex file since code in the test
  .exs files won't be automatically distributed to remote nodes during testing.
  (We could do it manually but this is much easier)
  """

  use GenServer, restart: :permanent

  def start_link(name) do
    case GenServer.start_link(__MODULE__, [], name: name) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, _pid}} ->
        :ignore
    end
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    IO.inspect("Starting on #{inspect(node())}")
    {:ok, nil}
  end

  def is_test?(p), do: GenServer.call(p, :is_test)

  def handle_call(:is_test, _from, s) do
    {:reply, true, s}
  end

  def terminate(reason, _s) do
    IO.inspect(node())
    IO.inspect("Terminating with #{inspect(reason)}")
  end
end

defmodule TestUtils do
  @moduledoc """
  Some test utilities to be run on remote nodes. These must be provided as an
  .ex file since code in the test .exs files won't be automatically distributed
  to remote nodes during testing.
  (We could do it manually but this is much easier)
  """

  import ExUnit.Assertions
  import Eventually

  def test_exists?(name, pid) do
    assert_eventually(Horde.Registry.whereis(Loner.name(name)) == [{pid, nil}])
    assert_eventually(DynamicSupervisor.which_children(Loner.DynamicSupervisor) != [])
    assert TestServer.is_test?(pid)
    assert TestServer.is_test?(Loner.name(name))
    true
  end
end

defmodule DistStrat do
  @behaviour Horde.DistributionStrategy

  def choose_node(_id, members), do: {:ok, List.last(members)}
  def has_quorum?(_members), do: true
end
