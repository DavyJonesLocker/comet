defmodule CometTest.Supervisor do
  use ExUnit.Case

  @moduletag :capture_log

  defmodule TabWorker do
    use Comet.TabWorker
  end

  defmodule CustomCacheWorker do
    use GenServer

    def start_link() do
      GenServer.start_link(__MODULE__, [], name: :custom_cache_worker)
    end

    def child_spec(_opts) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, []},
        restart: :permanent,
        type: :worker
      }
    end
  end

  test "init can ignore" do
    :ignore = Comet.Supervisor.init(:ignore)
  end

  test "supervisor only starts chrome and pool of tab workers by default" do
    opts = [
      pool: [
        worker_module: TabWorker
      ],
      worker: [
        launch_url: "about:blank"
      ]
    ]
    {:ok, pid} = start_supervised({Comet.Supervisor, opts})
    assert Supervisor.count_children(pid).workers == 2
  end

  test "starts CustomCacheWorker when given to `cache_worker` in opts" do
    opts = [
      cache_worker: CustomCacheWorker,
      pool: [
        worker_module: TabWorker
      ],
      worker: [
        launch_url: "about:blank"
      ]
    ]
    {:ok, pid} = start_supervised({Comet.Supervisor, opts})
    assert Supervisor.count_children(pid).workers == 3
  end
end