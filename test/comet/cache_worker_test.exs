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

  test "can insert into the ets table via function", %{pid: pid} do
    Comet.CacheWorker.insert("/foo", "bar")
    :sys.get_state(pid)
    [{"/foo", "bar"}] = :ets.lookup(:comet_cache, "/foo")
  end

  test "can expire specific keys via function", %{pid: pid} do
    :ets.insert(:comet_cache, {"/foo", "bar"})
    :ets.insert(:comet_cache, {"/baz", "qux"})
    Comet.CacheWorker.expire("/foo")
    :sys.get_state(pid)
    [] = :ets.lookup(:comet_cache, "/foo")
    [{"/baz", "qux"}] = :ets.lookup(:comet_cache, "/baz")
  end

  test "can expire all keys via function", %{pid: pid} do
    :ets.insert(:comet_cache, {"/foo", "bar"})
    :ets.insert(:comet_cache, {"/baz", "qux"})
    Comet.CacheWorker.expire_all()
    :sys.get_state(pid)
    [] = :ets.lookup(:comet_cache, "/foo")
    [] = :ets.lookup(:comet_cache, "/baz")
  end

  test "can get from with a key via function" do
    :ets.insert(:comet_cache, {"/foo", "bar"})
    "bar" = Comet.CacheWorker.get("/foo")
  end
end