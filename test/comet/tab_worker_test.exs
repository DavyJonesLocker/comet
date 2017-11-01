defmodule CometTest.TabWorker do
  use ExUnit.Case

  @moduletag :capture_log

  defmodule TabWorker do
    use Comet.TabWorker

    def before_launch([launch_url: "known error"], _state) do
      {:error, "known error"}
    end
    def before_launch([launch_url: "unknown error"], _state) do
      :error
    end
    def before_launch([launch_url: "data:text/html,before_launch_override"], state) do
      {:ok, Map.put(state, :before_launch, true)}
    end
    def before_launch(_opts, state), do: {:ok, state}

    def after_launch([launch_url: "data:text/html,after_launch_override"], state) do
      {:ok, Map.put(state, :after_launch, true)}
    end
    def after_launch(_opts, state), do: {:ok, state}

    def before_navigate([launch_url: "data:text/html,before_navigate_override"], state) do
      {:ok, Map.put(state, :before_navigate, true)}
    end
    def before_navigate(_opts, state), do: {:ok, state}

    def after_navigate([launch_url: "data:text/html,after_navigate_override"], state) do
      {:ok, Map.put(state, :after_navigate, true)}
    end
    def after_navigate(_opts, state), do: {:ok, state}

    def before_visit("/before_visit", _state) do
      "/before_visit?foo=true"
    end
    def before_visit(path, state), do: super(path, state)

    def visit("/before_visit?foo=true", %{pid: pid}) do
      Comet.promise_eval(pid, "Promise.resolve({status: 200, body: 'before_visit'})")
    end
    def visit("/visit", %{pid: pid}) do
      Comet.promise_eval(pid, "Promise.resolve({status: 200, body: 'visit'})")
    end
    def visit("/after_visit", %{pid: pid}) do
      Comet.promise_eval(pid, "Promise.resolve({status: 201, body: 'visit'})")
    end
    def visit(path, state), do: super(path, state)

    def after_visit(%{status: 201, body: "visit"} = response, _state) do
      %{response | body: "after_visit"}
    end
    def after_visit(response, state), do: super(response, state)

    def after_request(%{tries: 0} = state) do
      %{state | tries: 1}
    end
    def after_request(state), do: super(state)
  end

  setup do
    opts = [launch_url: "data:text/html,<h1>Hello World</h1>"]
    {:ok, chrome_pid} = start_supervised(ChromeLauncher)
    {:ok, worker_pid} = start_supervised(%{id: TabWorker, start: {TabWorker, :start_link, [opts]}})
    {:ok, %{chrome_pid: chrome_pid, worker_pid: worker_pid}}
  end

  describe "init lifecycle" do
    test "init can ignore" do
      :ignore = TabWorker.init(:ignore)
    end

    test "when worker inits navigates to `launch_url`", %{worker_pid: worker_pid} do
      %{pid: tab_pid} = :sys.get_state(worker_pid)
      {:ok, %{"result" => %{"entries" => entries}}} = ChromeRemoteInterface.RPC.Page.getNavigationHistory(tab_pid)
      [%{"url" => "about:blank"}, %{"url" => "data:text/html,<h1>Hello World</h1>"}] = entries
    end

    test "before_launch can be overridden" do
      opts = [launch_url: "data:text/html,before_launch_override"]
      {:ok, state} = TabWorker.init(opts)
      assert state.before_launch
    end

    test "after_launch can be overridden" do
      opts = [launch_url: "data:text/html,after_launch_override"]
      {:ok, state} = TabWorker.init(opts)
      assert state.after_launch
    end

    test "before_navigate can be overridden" do
      opts = [launch_url: "data:text/html,before_navigate_override"]
      {:ok, state} = TabWorker.init(opts)
      assert state.before_navigate
    end

    test "after_navigate can be overridden" do
      opts = [launch_url: "data:text/html,after_navigate_override"]
      {:ok, state} = TabWorker.init(opts)
      assert state.after_navigate
    end

    test "init returns {:stop, reason} when known error occurs" do
      opts = [launch_url: "known error"]
      {:stop, "known error"} = TabWorker.init(opts)
    end

    test "init returns {:stop, :unknown} when unknown error occurs" do
      opts = [launch_url: "unknown error"]
      {:stop, {:unknown, :error}} = TabWorker.init(opts)
    end
  end

  describe "request lifecycle" do
    test "default visit returns 501", %{worker_pid: worker_pid} do
      resp = GenServer.call(worker_pid, {:request, "/"})

      assert resp.status == 501
      assert String.contains?(resp.body, "Not Implemented")
    end

    test "before_visit can be overridden", %{worker_pid: worker_pid} do
      %{status: 200, body: "before_visit"} = GenServer.call(worker_pid, {:request, "/before_visit"})
    end

    test "visit can be overridden", %{worker_pid: worker_pid} do
      %{status: 200, body: "visit"} = GenServer.call(worker_pid, {:request, "/visit"})
    end

    test "after visit can be overridden", %{worker_pid: worker_pid} do
      %{status: 201, body: "after_visit"} = GenServer.call(worker_pid, {:request, "/after_visit"})
    end

    test "after_request can be overridden", %{worker_pid: worker_pid} do
      :sys.replace_state(worker_pid, fn(state) -> Map.put(state, :tries, 0) end)    
      GenServer.cast(worker_pid, :after_request)
      %{tries: 1} = :sys.get_state(worker_pid)
    end
  end
end