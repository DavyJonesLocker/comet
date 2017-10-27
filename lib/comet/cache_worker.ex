defmodule Comet.CacheWorker do
  use GenServer

  @name :comet_cache

  @moduledoc """
  Generic cache `ets` based cache worker

  This cache worker has a lifecycle tied to the `Comet.Supervisor` process. If that process
  dies the `ets` table associated with this cache is lost.

  This cache will work off of the request path being the unique key to retrieve against.

  You can interact with the cache with `GenServer.cast/2` and `GenServer.call/2`
  Or you can use the `get/1`, `insert/2`, `expire/1`, `expire/0` functions.
  """

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @doc false
  def init(:ok) do
    table = :ets.new(:comet_cache, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @doc """
  Non-blocking handler for the cache worker

  The following commands are available via `GenServer.cast/2`

  * `{:insert, path, resp}` - inserts a new response object for the given request path
  * `{:expire, path}` - expires a cache key for a given request path
  * `{:expire_all}` - expires the entire cache
  """
  def handle_cast({:insert, path, resp}, %{table: table} = state) do
    :ets.insert(table, {path, resp})
    {:noreply, state}
  end
  def handle_cast({:expire, path}, %{table: table} = state) do
    :ets.delete(table, path)
    {:noreply, state}
  end
  def handle_cast(:expire_all, %{table: table} = state) do
    :ets.delete_all_objects(table)
    {:noreply, state}
  end

  @doc """
  Blocking handler for the cache worker

  The following command is availalbe via `GenServer.call/2`

  * `{:get, path}` return the response object stored for the given request path
  """
  def handle_call({:get, path}, _from, %{table: table} = state) do
    result = case :ets.lookup(table, path) do
      [{^path, resp}] -> resp 
      [] -> :no_cache
    end

    {:reply, result, state}
  end

  @doc """
  Get a value from the cache for a given key

  ## Example

      "bar" = Comet.CacheWorker.get("foo")
  """
  def get(key) do
    GenServer.call(@name, {:get, key})
  end

  @doc """
  Insert a value for a given key into the cache

  ## Example

      Comet.CacheWorker.insert("/foo", "bar")
  """
  def insert(key, value) do
    GenServer.cast(@name, {:insert, key, value})
  end

  @doc """
  Expire a given key/value pair in the cache

  ## Example

      Comet.CacheWorker.expire("/foo")
  """
  def expire(key) do
    GenServer.cast(@name, {:expire, key})
  end

  @doc """
  Expire all key/value pairs in the cache

  ## Example

      Comet.CacheWorker.expire_all()
  """
  def expire_all() do
    GenServer.cast(@name, :expire_all)
  end
end
