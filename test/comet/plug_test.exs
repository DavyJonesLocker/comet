defmodule CometTest.Plug do
  use ExUnit.Case
  use Plug.Test

  @moduletag :capture_log

  defmodule TabWorker do
    use Comet.TabWorker

    # we are using the `body` to return the value of
    # `path` for assertion testing
    def visit(path, %{pid: pid}) do
      Comet.eval(pid, "Promise.resolve({status: 200, body: '#{path}'})")
    end
  end

  defmodule MyPlug do
    use Comet.Plug

    def build_query("foo=bar") do
      Map.put(%{}, "other", false)
      |> URI.encode_query()
    end

    # we use overridden function defs to
    # manage different outcomes for the tests
    def build_query(query_string) do
      super(query_string)
    end

    def build_path(["foo"], query) do
      super(["bar"], query)
    end

    def build_path(path, query) do
      super(path, query)
    end

    def handle_response(_response, %Plug.Conn{private: %{plug_session: %{"foo" => "bar"}}} = conn) do
      put_resp_content_type(conn, "application/json")
    end
    def handle_response(response, conn) do
      super(response, conn)
    end
  end

  defmodule MyCachePlug do
    use Comet.Plug, cache: Comet.Cache
  end

  defmodule MyScopedPlug do
    use Comet.Plug, scope: "other-ssr"
  end

  defmodule MyQueryParamPlug do
    use Comet.Plug, query_param: "other-ssr"
  end

  setup do
    opts = [
      worker: [
        launch_url: "data:text/html,<h1>Hello World</h1>"
      ],
      pool: [
        worker_module: TabWorker
      ],
      cache_worker: Comet.CacheWorker
    ]
    {:ok, pid} = start_supervised({Comet.Supervisor, opts})
    {:ok, pid: pid}
  end

  test "request not nested under `/ssr` plug is pass-through" do
    response =
      conn(:get, "/foo")
      |> MyPlug.call([])
    
      assert response.halted == false 
      assert is_nil(response.resp_body)
  end

  test "request is nested under `/ssr` plug visits" do
    response =
      conn(:get, "/ssr")
      |> MyPlug.call([])

    assert response.halted
    ["text/html; charset=utf-8"] = Plug.Conn.get_resp_header(response, "content-type")
    200 = response.status
    "/?ssr=true" = response.resp_body
  end

  test "can override build_query/1" do
    response =
      conn(:get, "/ssr?foo=bar")
      |> MyPlug.call([])

    assert response.halted
    ["text/html; charset=utf-8"] = Plug.Conn.get_resp_header(response, "content-type")
    200 = response.status
    "/?other=false" = response.resp_body
  end

  test "can override build_path/2" do
    response =
      conn(:get, "/ssr/foo")
      |> MyPlug.call([])

    assert response.halted
    ["text/html; charset=utf-8"] = Plug.Conn.get_resp_header(response, "content-type")
    200 = response.status
    "/bar?ssr=true" = response.resp_body
  end

  test "can override handle_response/2" do
    response =
      conn(:get, "/ssr")
      |> Plug.Test.init_test_session(%{foo: "bar"})
      |> MyPlug.call([])

    ["application/json; charset=utf-8"] = Plug.Conn.get_resp_header(response, "content-type")
  end

  test "request is not cached" do
    conn(:get, "/ssr")
    |> MyPlug.call([])

    [] = :ets.lookup(:comet_cache, "/")
  end

  test "request is cached when plug is configured for caching" do
    conn(:get, "/ssr")
    |> MyCachePlug.call([])

    :sys.get_state(:comet_cache)

    [{"/?ssr=true", %{status: 200, body: "/?ssr=true"}}] = :ets.lookup(:comet_cache, "/?ssr=true")
  end

  test "serves response from cache" do
    :ets.insert(:comet_cache, {"/?ssr=true", %Comet.Response{status: 418, body: "I'm a teapot"}})
    response =
      conn(:get, "/ssr")
      |> MyCachePlug.call([])

    418 = response.status
    "I'm a teapot" = response.resp_body
  end

  test "can use other scopes" do
    response =
      conn(:get, "/other-ssr")
      |> MyScopedPlug.call([])

    assert response.halted
    ["text/html; charset=utf-8"] = Plug.Conn.get_resp_header(response, "content-type")
    200 = response.status
    "/?other-ssr=true" = response.resp_body
  end

  test "can customize query_param" do
    response =
      conn(:get, "/ssr")
      |> MyQueryParamPlug.call([])

    assert response.halted
    ["text/html; charset=utf-8"] = Plug.Conn.get_resp_header(response, "content-type")
    200 = response.status
    "/?other-ssr=true" = response.resp_body
  end
end
