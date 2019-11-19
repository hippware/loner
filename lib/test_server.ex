defmodule TestServer do
  @moduledoc """
  Very simple test server - defined here rather than under `test/` so that it
  gets loaded to remote nodes by LocalCluster
  """

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Loner.name(__MODULE__))
  end

  def init(_) do
    {:ok, nil}
  end

  def is_test?(pid), do: GenServer.call(pid, :is_test?)

  def handle_call(:is_test?, _from, state), do: {:reply, true, state}
end
