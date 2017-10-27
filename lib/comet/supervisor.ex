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

        supervisor(Comet.Supervisor, [Application.get_env(:comet, :supervisor, :ignore), Application.get_env(:comet, :worker, :ignore)])
      ]
  """

  @default_pool_opts [
    name: {:local, :comet_pool},
    size: 1,
    max_overflow: 0,
    strategy: :fifo
  ]

  # def start_link([pool_opts, worker_opts]) do
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: :comet_supervisor)
  end

  @doc """
  Init the Supervisor

  The `init` function takes two arguments:

  * `poolboy_supervisor_args` - Please see poolboy's documentation on args.
  * `poolboy_worker_args` - These args are used with `Comet.TabWorker`

  This supervisor uses a `rest_for_one` strategy. The order of the supervised processes:

  1. `Comet.CacheWorker`
  1. `Comet.ChromeWorker`
  1. `:poolboy`
  """
  def init(:ignore), do: :ignore
  def init([pool_opts, worker_opts]) do
    pool_opts = Keyword.merge(@default_pool_opts, pool_opts)

    children = [
      worker(Comet.CacheWorker, []),
      worker(ChromeLauncher, []),
      :poolboy.child_spec(:comet_pool, pool_opts, worker_opts)
    ]

    supervise(children, strategy: :rest_for_one)
  end
end