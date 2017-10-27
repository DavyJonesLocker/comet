defmodule CometTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = start_supervised(ChromeLauncher)
    {:ok, pid: pid}
  end

  test "server returns new Chrome server instance" do
    %ChromeRemoteInterface.Server{host: "localhost", port: 9222} = Comet.server()
  end

  test "can create a new tab and pid" do
    server = Comet.server()

    {tab, pid} = Comet.new_tab(server)

    assert is_pid(pid)
    assert get_in(tab, ["id"])
  end

  test "can close an open tab" do
    server = Comet.server()
    {tab, pid} = Comet.new_tab(server)
    {:ok, pages} = ChromeRemoteInterface.Session.list_pages(server)
    page_count = length(pages)
    Comet.close_tab(server, tab, pid)

    {:ok, pages} = receive do
      # Because closing a tab is async
      # and we don't get back any message
      # signaling the close has completed we simply
      # pause execution for a short period to allow
      # the tab to completely close
    after 100 ->
      ChromeRemoteInterface.Session.list_pages(server)
    end

    assert length(pages) == (page_count - 1)
  end

  test "enable a tab" do
    server = Comet.server()
    {_tab, pid} = Comet.new_tab(server)
    {:ok, %{"id" => _id, "result" => _result}} = Comet.enable(pid)
  end

  test "navigate to" do
    server = Comet.server()
    {_tab, pid} = Comet.new_tab(server)
    url = "data:text/html,<h1>Hello World</h1>"
    Comet.enable(pid)
    Comet.navigate_to(pid, url)

    {:ok, %{"result" => %{"result" => %{"value" => ^url}}}} = receive do
      {:chrome_remote_interface, "Page.loadEventFired", _data} ->
        ChromeRemoteInterface.RPC.Runtime.evaluate(pid, %{expression: "location.href"})
    after
      1_000 -> :fail
    end
  end

  test "promise_eval" do
    server = Comet.server()
    {_tab, pid} = Comet.new_tab(server)
    url = "data:text/html,<h1>Hello World</h1>"
    Comet.enable(pid)
    Comet.navigate_to(pid, url)
    value = "{foo: 'bar'}"
    Comet.promise_eval(pid, "Promise.resolve(#{value})")

    :ok = receive do
      {:chrome_remote_interface, "Runtime.evaluate", %{"result" => %{"result" => %{"value" => %{"foo" => "bar"}}}}} -> :ok
    after
      1_000 -> :fail
    end
  end
end
