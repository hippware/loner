defmodule TestServer do
  @moduledoc """
  Very simple test server - defined here rather than under `test/` so that it
  gets loaded to remote nodes by LocalCluster
  """

  use GenServer, restart: :transient

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Loner.name(__MODULE__))
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    IO.inspect "STARTING #{inspect self()} - #{inspect node()}"
    {:ok, nil, 500}
  end

  def is_test?(pid), do: GenServer.call(pid, :is_test?)

  def handle_call(:is_test?, _from, state), do: {:reply, true, state, 500}

  def handle_info({:EXIT, _, {:name_conflict, _, _, _}} = m, state) do
    IO.inspect "#{inspect self()} - #{inspect m} - #{inspect node()}"
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    IO.inspect "PING #{inspect self()} - #{inspect node()}"
    {:noreply, state, 500}
  end
end

defmodule TestSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: TestSupervisor)
  end

  def init(_) do
    children = [
      RegisteredServer
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end

defmodule RegisteredServer do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    {:ok, nil}
  end
end
