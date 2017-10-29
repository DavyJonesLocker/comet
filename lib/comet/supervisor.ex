defmodule Comet.Supervisor do
  use Supervisor

  @moduledoc """
  Primary Supervisor for Comet

  This Supervisor will manage the `ChromeLauncher` and `:poolboy`. You can opt-in to
  the Supervisor managing `Comet.CacheWorker`.

  This Supervisor should be used directly in your own app's supervisor tree. You must pass in
  the options for configuring the workers. All of the options available:

  * `pool:` - the keyword list of pool options passed to `:poolboy.child_spec/3` as the 2nd argument. Please refer to `:poolboy`'s documentation for greater detail.
    * `name:` - defaults to `{:local, :comet_pool}` (you probably shouldn't change this one)
    * `size:` - default to `1`
    * `max_overflow:` - defaults to `0`
    * `strategy:` - defaults to `:fifo` (you probably shouldn't change this one)
    * `worker_module:` **(required)** the module in your app that used `Comet.TabWorker`
  * `worker:` - the keyword list of worker options passed to `:poolboy.child_spec/3` as the 3rd arugment and used by your `TabWorker` module.
    * `launch_url:` - **(required)** the url a new tab will navigate to to ready itself for inbound requests. *Note: `launch_url:` while required for usage it is currently flaged as non-public API and subject to change in the future. We will do our best to manage the debt*.
  * `cache_worker:` - allow you to opt-in to having `Comet.Supervisor` manage a cache. The advantage here is the cache itself will be tied to the lifecycle of the Supervisor
  and can be restarted at the appropriate time if necessary.
  Valid options:
    * `true` - will opt-in to `Comet.CacheWorker`
    * `Comet.CacheWorker` - you can supply the module directly
    * Your own custom caching module. If you go this route, please refer to `Comet.CacheWorker`'s documentation.

  ## Example config

      config :my_app, :comet,
        pool: [
          size: 5,
          worker_module: MyApp.TabWorker
        ],
        worker: [
          launch_url: "https://example.com"
        ],
        cache_worker: MyApp.CustomCacheWorker

  In environments you do not want to run Comet just pass `:ignore` as the opts value. A simple way to do this is to only define the config
  you want to use in the environments that will use Comet, with a default config value of `:ignore`

  ## Example supervisor setup

  **Note that this example uses the [Elixir 1.5 supervisor syntax](https://github.com/elixir-lang/elixir/blob/v1.5/CHANGELOG.md#streamlined-child-specs).**

      children = [
        ...
        {Comet.Supervisor, Application.get_env(:my_app, :comet, :ignore)}
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