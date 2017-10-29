defmodule CometTest.CacheWorker do
  use ExUnit.Case

  setup do
    {:ok, pid} = start_supervised(%{id: Comet.CacheWorker, start: {Comet.CacheWorker, :start_link, []}})
    {:ok, %{pid: pid}}
  end

  test "when the worker inits the table is created" do
    info = :ets.info(:comet_cache)

    assert info != :undefined
  end
end