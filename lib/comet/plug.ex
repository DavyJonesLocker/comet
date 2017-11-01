defmodule Comet.Plug do
  @moduledoc """
  Plug macro module for use in your application.

  This module will handle the inbound requests for your application.
  By default it assumes anything nested under `/ssr` should be delegated
  to the tab worker for rendering.

  This module cannot be used directly, it should be `use`d in your app:

  ### Example

      defmodule MyApp.Plugs.SSR do
        use Comet.Plug
      end

  Please refer to the public functions documented below.
  Each publicly documented function can be overriden in your
  custom module.

  You can change the URL `scope` this plug works under as well as the `query_param`
  appended to the `path`:

      defmodule MyApp.Plugs.SSR do
        use Comet.Plug, scope: "other-ssr", query_param: "foobar"
      end

  If you do not define `query_param` it will inherit the value for `scope`.

  ## Caching

  This plug can be set up to cache all responses for a given unique path. The
  cached response will be used on the next request. This can significantly
  increase the performance of your application. If you'd like to opt-into
  the cache:

      defmodule MyApp.Plug.SSR do
        use Comet.Plug, cache: Comet.Cache
      end

  If you'd like to use your own custom cache module:

      defmodule MyApp.Plug.SSR do
        use Comet.Plug, cache: MyCacher
      end

  Your cache module must respond to `get/1` and `insert/2`. See the definitions of
  those functions in `Comet.Cache` for more details.

  Please note that only responses with status codes within the 200..299 range are cached.
  All other responses are not cached.
  """

  Module.add_doc(__MODULE__, 92, :def, {:build_query, 1}, (quote do: [query_string]), """
  Injects the `ssr=true` query param and return a new `query_string`
  
  You can override this function.
  """)

  Module.add_doc(__MODULE__, 99, :def, {:build_path, 2}, (quote do: [path, query_string]), """
  Joins the original `path` and `query_string` into a single path

  ## Example

      build_path("/foo/bar", "ssr=true&baz=qux")
      "/foo/bar?ssr=true&baz=qux"

  You can override this function.
  """)

  Module.add_doc(__MODULE__, 103, :def, {:handle_response, 2}, (quote do: [conn, response]), """
  Sets the proper response in the `conn`.

  Sets the `resp_body`, `resp_headers, and `status` of the `conn`.

  Will `halt` any more Plugs.

  You can override this function.
  """)

  defmacro __using__(opts) do
    scope = Keyword.get(opts, :scope, "ssr")
    query_param = Keyword.get(opts, :query_param, scope)
    cache_mod = Keyword.get(opts, :cache)

    quote do
      import Plug.Conn

      @scope unquote(scope)
      @query_param unquote(query_param)
      @cache_mod unquote(cache_mod)
      @pool :comet_pool

      def init(_opts), do: nil
      def call(%{method: "GET", path_info: [@scope | path], query_string: query_string} = conn, _opts) do
        query = build_query(query_string)

        path
        |> build_path(query)
        |> get_for()
        |> handle_response(conn)
      end
      def call(conn, _opts), do: conn

      def build_query(query_string) do
        query_string
        |> URI.decode_query()
        |> Map.put(@query_param, true)
        |> URI.encode_query()
      end

      def build_path(path, query) do
        "/" <> Enum.join(path, "/") <> "?" <> query
      end

      def handle_response(%Comet.Response{body: body, headers: headers, status: status}, conn) do
        conn
        |> merge_resp_headers(headers)
        |> send_resp(status, body)
        |> halt()
      end

      defoverridable [
        build_query: 1,
        build_path: 2,
        handle_response: 2
      ]

      defp get_for(path) do
        case get_cache_for(path) do
          :no_cache -> get_no_cache_for(path)
          response -> response
        end
      end

      if @cache_mod do
        defp get_cache_for(path) when not is_nil(@cache_mod), do: @cache_mod.get(path)
      end
      defp get_cache_for(_path), do: :no_cache

      defp get_no_cache_for(path) do
        worker_pid = :poolboy.checkout(@pool)
        response =
          GenServer.call(worker_pid, {:request, path}, :infinity)
          |> cache_response(path)

        GenServer.cast(worker_pid, :after_request)

        response
      end

      if @cache_mod do
        defp cache_response(%Comet.Response{status: status} = response, path) when not is_nil(@cache_mod) and status in 200..299 do
          @cache_mod.insert(path, response)

          response
        end
      end
      defp cache_response(%Comet.Response{} = response, _path), do: response
    end
  end
end
