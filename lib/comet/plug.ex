defmodule Comet.Plug do
  @moduledoc """
  Plug macro module for use in your application.

  This module will handle the inbound requests for your application.
  By default it assumes anything nested under `/ssr/` should be delegated
  to the tab worker for rendering.

  This module cannot be used directly, it should be `use`d in your app:

  ### Example

      defmodule MyApp.Plugs.SSR do
        use Comet.Plug
      end

  Please refer to the public functions documented below.
  Each publicly documented function can be overriden in your
  custom module.


  ## Caching

  This plug can be set up to cache all responses for a given unique path. The
  cached response will be used on the next request. This can significantly
  increase the performance of your application. If you'd like to opt-into
  the cache:

      defmodule MyApp.Plug.SSR do
        use Comet.Plug, cache: true
      end

  When you opt into the cache with `cache: true` the `Comet.CacheWorker` cache
  will be used. If you'd like to use your own custom cache module:

      defmodule MyApp.Plug.SSR do
        use Comet.Plug, cache: MyCacher
      end

  Your cache module must respond to `get/1` and `insert/2`. See the definitions of
  those functions in `Comet.CacheWorker` for more details.
  """

  Module.add_doc(__MODULE__, 71, :def, {:build_query, 1}, (quote do: [query_string]), """
  Injects the `ssr=true` query param and return a new `query_string`
  
  You can override this function.
  """)

  Module.add_doc(__MODULE__, 78, :def, {:build_path, 2}, (quote do: [path, query_string]), """
  Joins the original `path` and `query_string` into a single path

  ## Example

      build_path("/foo/bar", "ssr=true&baz=qux")
      "/foo/bar?ssr=true&baz=qux"

  You can override this function.
  """)

  Module.add_doc(__MODULE__, 82, :def, {:handle_response, 2}, (quote do: [conn, response]), """
  Sets the proper response in the `conn`.

  The content-type for the response is set to `"text/html"`.
  
  If the `status` is a String, convert to an Integer.

  Sets the `status` and `body` of the `conn`.

  Will `halt` any more Plugs.

  You can override this function.
  """)

  defmacro __using__(opts) do
    using(opts)
  end

  defp using([]) do
    using([cache: false])
  end
  defp using([cache: true]) do
    using([cache: Comet.CacheWorker])
  end
  defp using([cache: cache_mod]) do
    quote do
      import Plug.Conn

      @cache_mod unquote(cache_mod)
      @pool :comet_pool

      def init(_opts), do: nil
      def call(%{method: "GET", path_info: ["ssr" | path], query_string: query_string} = conn, _opts) do
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
        |> Map.put("ssr", true)
        |> URI.encode_query()
      end

      def build_path(path, query) do
        "/" <> Enum.join(path, "/") <> "?" <> query
      end

      def handle_response(%{status: status} = response, conn) when is_binary(status) do
        handle_response(%{response | status: String.to_integer(status)}, conn)
      end
      def handle_response(%{status: status, resp_body: body}, conn) do
        conn
        |> put_resp_content_type("text/html")
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

      defp get_cache_for(path) when @cache_mod != false do
        @cache_mod.get(path)
      end
      defp get_cache_for(_) when @cache_mod == false, do: :no_cache

      defp get_no_cache_for(path) do
        worker_pid = :poolboy.checkout(@pool)
        response =
          GenServer.call(worker_pid, {:request, path})
          |> cache_response(path)

        GenServer.cast(worker_pid, :after_request)

        response
      end

      defp cache_response(response, path) when @cache_mod != false do
        @cache_mod.insert(path, response)

        response
      end
      defp cache_response(response, _path) when @cache_mod == false, do: response
    end
  end
end
