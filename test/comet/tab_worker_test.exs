defmodule CometTest.TabWorker do
  use ExUnit.Case

  @moduletag :capture_log

  defmodule TabWorker do
    use Comet.TabWorker

    def before_visit("/before_visit", _state) do
      "/before_visit?foo=true"
    end
    def before_visit(path, state), do: super(path, state)

    def visit("/before_visit?foo=true", %{pid: pid}) do
      Comet.promise_eval(pid, "Promise.resolve({status: 200, resp_body: 'before_visit'})")
    end
    def visit("/visit", %{pid: pid}) do
      Comet.promise_eval(pid, "Promise.resolve({status: 200, resp_body: 'visit'})")
    end
    def visit("/after_visit", %{pid: pid}) do
      Comet.promise_eval(pid, "Promise.resolve({status: 201, resp_body: 'visit'})")
    end
    def visit(path, state), do: super(path, state)

    def after_visit(%{status: 201, resp_body: "visit"} = response, _state) do
      %{response | resp_body: "after_visit"}
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

  test "when worker inits navigates to `launch_url`", %{worker_pid: worker_pid} do
    %{pid: tab_pid} = :sys.get_state(worker_pid)
    {:ok, %{"result" => %{"entries" => entries}}} = ChromeRemoteInterface.RPC.Page.getNavigationHistory(tab_pid)
    [%{"url" => "about:blank"}, %{"url" => "data:text/html,<h1>Hello World</h1>"}] = entries
  end

  test "default visit returns 501", %{worker_pid: worker_pid} do
    resp = GenServer.call(worker_pid, {:request, "/"})

    assert resp.status == 501
    assert String.contains?(resp.resp_body, "Not Implemented")
  end

  test "before_visit can be overridden", %{worker_pid: worker_pid} do
    %{status: 200, resp_body: "before_visit"} = GenServer.call(worker_pid, {:request, "/before_visit"})
  end

  test "visit can be overridden", %{worker_pid: worker_pid} do
    %{status: 200, resp_body: "visit"} = GenServer.call(worker_pid, {:request, "/visit"})
  end

  test "after visit can be overridden", %{worker_pid: worker_pid} do
    %{status: 201, resp_body: "after_visit"} = GenServer.call(worker_pid, {:request, "/after_visit"})
  end

  test "after_request can be overridden", %{worker_pid: worker_pid} do
    :sys.replace_state(worker_pid, fn(state) -> Map.put(state, :tries, 0) end)    
    GenServer.cast(worker_pid, :after_request)
    %{tries: 1} = :sys.get_state(worker_pid)
  end
end