defmodule TestServer do
  use GenServer, restart: :transient

  def start_link(name) do
    case GenServer.start_link(__MODULE__, [], name: name) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, _pid}} ->
        :ignore
    end
  end

  def init(_), do: {:ok, nil}

  def exit(p, reason \\ :normal), do: GenServer.call(p, {:exit, reason})

  def is_test?(p), do: GenServer.call(p, :is_test)

  def handle_call({:exit, reason}, _from, s), do: {:stop, reason, :ok, s}

  def handle_call(:is_test, _from, s), do: {:reply, true, s}
end
