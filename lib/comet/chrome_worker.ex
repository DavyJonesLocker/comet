defmodule Comet.ChromeWorker do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, pid} = ChromeLauncher.launch()

    {:ok, %{pid: pid}}
  end

  def handle_info({:tcp_closed, _pid}, state) do
    GenServer.stop(self())
    {:noreply, state}
  end
end