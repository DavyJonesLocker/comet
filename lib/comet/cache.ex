defmodule Comet.Cache do
  require Comet.CacheWorker
  @moduledoc """
  Generic `:ets` based cache
  This cache will work off of the request path being the unique path to retrieve against.

  You can use the `get/1`, `insert/2`, `expire/1`, `expire_all/0` functions.

  ## Using your own custom cache
  If you decide to provide your own custom cache you should use the `@behaviour` provided
  by this module. You **must** define `get/1` and `insert/2` as required by the behaviour:

  ## Example

      defmodule MyApp.CustomCache do
        @behaviour Comet.Cache

        def get(path) do
          ...
        end

        def insert(path, response) do
          ...
        end
      end
  """

  @callback get(path :: String) :: %Comet.Response{body: String, headers: List, status: Integer}
  @callback insert(path :: String, response :: %Comet.Response{body: String, headers: List, status: Integer}) :: term

  Comet.CacheWorker.use_name()

  @doc """
  Get a response from the cache for a given path

  ## Example

      "bar" = Comet.CacheWorker.get("foo")
  """
  def get(path) do
    case :ets.lookup(@name, path) do
      [{^path, %Comet.Response{} = response}] -> response
      [] -> :no_cache
    end
  end

  @doc """
  Insert a response for a given path into the cache

  ## Example

      Comet.CacheWorker.insert("/foo", "bar")
  """
  def insert(path, %Comet.Response{} = response) do
    :ets.insert(@name, {path, response})
  end

  @doc """
  Expire a given path/response pair in the cache

  ## Example

      Comet.CacheWorker.expire("/foo")
  """
  def expire(path) do
    :ets.delete(@name, path)
  end

  @doc """
  Expire all path/response pairs in the cache

  ## Example

      Comet.CacheWorker.expire_all()
  """
  def expire_all() do
    :ets.delete_all_objects(@name)
  end
end
