defmodule TestServer do
  use GenServer, restart: :permanent

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name) do
  end

  def init(_) do
    {:ok, nil}
  end
end

defmodule DistStrat do
  @behaviour Horde.DistributionStrategy

  def choose_node(_id, members), do: {:ok, List.last(members)}
  def has_quorum?(_members), do: true
end
