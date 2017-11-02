defmodule CometTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup do
    {:ok, pid} = start_supervised(ChromeLauncher)
    {:ok, pid: pid}
  end

  test "server returns new Chrome server instance" do
    %ChromeRemoteInterface.Server{host: "localhost", port: 9222} = Comet.server()
  end

  test "server can customize the host and port" do
    %ChromeRemoteInterface.Server{host: "example.com", port: 9555} = Comet.server(host: "example.com", port: 9555)
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
    :ok = Comet.navigate_to(pid, url)
    {:ok, %{"result" => %{"result" => %{"value" => ^url}}}} = ChromeRemoteInterface.RPC.Runtime.evaluate(pid, %{expression: "location.href"})
  end

  test "eval" do
    server = Comet.server()
    {_tab, pid} = Comet.new_tab(server)
    url = "data:text/html,<h1>Hello World</h1>"
    Comet.enable(pid)
    Comet.navigate_to(pid, url)
    value = "{foo: 'bar'}"
    {:ok, %{"foo" => "bar"}} = Comet.eval(pid, "Promise.resolve(#{value})")
    {:ok, [1, 2, 3]} = Comet.eval(pid, "[1, 2, 3]")
    {:error, "Object couldn't be returned by value"} = Comet.eval(pid, "Symbol.for('foo')")
    {:error, {"ReferenceError", "ReferenceError: foo is not defined\n    at <anonymous>:1:1"}} = Comet.eval(pid, "foo")
    {:reject, %{"foo" => "bar"}} = Comet.eval(pid, "Promise.reject(#{value})")
  end
end
