defmodule Comet.CacheWorker do
  use GenServer

  @name :comet_cache

  @moduledoc """
  Generic cache `ets` based cache worker

  This cache worker has a lifecycle tied to the `Comet.Supervisor` process. If that process
  dies the `ets` table associated with this cache is lost.

  This cache will work off of the request path being the unique key to retrieve against.

  You can use the `get/1`, `insert/2`, `expire/1`, `expire/0` functions.
  """

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @doc false
  def init(:ok) do
    table = :ets.new(@name, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @doc false
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :permanent,
      type: :worker
    }
  end

  @doc """
  Get a value from the cache for a given key

  ## Example

      "bar" = Comet.CacheWorker.get("foo")
  """
  def get(key) do
    case :ets.lookup(@name, key) do
      [{^key, value}] -> value
      [] -> :no_cache
    end
  end

  @doc """
  Insert a value for a given key into the cache

  ## Example

      Comet.CacheWorker.insert("/foo", "bar")
  """
  def insert(key, value) do
    :ets.insert(@name, {key, value})
  end

  @doc """
  Expire a given key/value pair in the cache

  ## Example

      Comet.CacheWorker.expire("/foo")
  """
  def expire(key) do
    :ets.delete(@name, key)
  end

  @doc """
  Expire all key/value pairs in the cache

  ## Example

      Comet.CacheWorker.expire_all()
  """
  def expire_all() do
    :ets.delete_all_objects(@name)
  end
end
