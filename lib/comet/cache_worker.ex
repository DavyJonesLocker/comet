defmodule Comet.CacheWorker do
  use GenServer

  @name :comet_cache

  @moduledoc """
  Generic `:ets` based cache worker

  This cache worker has a lifecycle tied to the `Comet.Supervisor` process. If that process
  dies the `:ets` table associated with this cache is lost.

  This cache will work off of the request path being the unique key to retrieve against.

  You can use the `get/1`, `insert/2`, `expire/1`, `expire_all/0` functions.

  If you decide to provide your own custom Cache please refer to the documentation in `Comet.Cache`.
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

  @doc false
  def name, do: @name
end
