defmodule Comet.Supervisor do
  use Supervisor

  @moduledoc """
  Primary Supervisor for Comet

  This Supervisor will manage the CacheWorker, ChromeWorker, and Poolboy.

  This Supervisor should be used directly in your own app's supervisor tree. It takes two arguments,
  the *pool_opts* and the *worker_opts*.

  ## Example:

      children = [
        ...
        {Comet.Supervisor, [Application.get_env(:my_app, :comet, :ignore)]}
      ]
  """

  @default_pool_opts [
    name: {:local, :comet_pool},
    size: 1,
    max_overflow: 0,
    strategy: :fifo
  ]

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: :comet_supervisor)
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :supervisor
    }
  end

  @doc false
  def init(:ignore), do: :ignore
  def init(opts) do
    left_merge = fn(_, v, _) -> v end
    pool_opts = 
      opts
      |> Keyword.get(:pool, [])
      |> Keyword.merge(@default_pool_opts, left_merge)

    worker_opts = Keyword.get(opts, :worker, [])
    children = [
      ChromeLauncher,
      :poolboy.child_spec(:comet_pool, pool_opts, worker_opts)
    ]

    Keyword.get(opts, :cache_worker)
    |> case do
      nil -> children
      false -> children
      true -> List.insert_at(children, 1, Comet.CacheWorker)
      mod -> List.insert_at(children, 1, mod)
    end
    |> Supervisor.init(strategy: :rest_for_one)
  end
end