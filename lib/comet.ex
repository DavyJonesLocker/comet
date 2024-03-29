defmodule Comet do
  @moduledoc """
  Primary functions for managing `ChromeRemoteInterface` connections

  This module adds some convenience functions when dealing with
  Chrome via the RPC and other funcitons. It isn't necessary to use these functions
  but it makes dealing with Chrome a bit nicer.
  """

  @doc """
  Returns a ChromeRemoteInterface server object.

  ## Options

  * `host` - the host of the Chrome server
  * `port` - the port the Chrome server is running on
  """
  def server(opts \\ []) do
    ChromeRemoteInterface.Session.new(opts)
  end

  @doc """
  Creates a new tab and pid for the tab

  ## Example

      Comet.server()
      |> Comet.new_tab()
  """
  def new_tab(server) do
    {:ok, tab} = ChromeRemoteInterface.Session.new_page(server)
    {:ok, pid} = ChromeRemoteInterface.PageSession.start_link(tab)

    {tab, pid}
  end

  @doc """
  Closes a tab and the associated PageSession.

  Closing a tab should call `terminate` on the tab's worker

  ## Example

      Comet.close_tab(server, tab, pid)
  """
  def close_tab(server, %{"id" => tab_id}, pid) do
    ChromeRemoteInterface.PageSession.stop(pid)
    ChromeRemoteInterface.Session.close_page(server, tab_id)
  end

  @doc """
  Enable a given `pid` for a tab
  """
  def enable(pid) do
    ChromeRemoteInterface.RPC.Page.enable(pid)
  end

  @doc """
  Instructs a tab to navigate to a givel URL and subscribes the tab to the `Page.loadEventFired` event.

  Take note that [Page.loadEventFired](https://chromedevtools.github.io/devtools-protocol/tot/Page/#event-loadEventFired) is
  a standard event in the Chrome Protocol.
  """
  def navigate_to(pid, url, timeout \\ 5000) do
    ChromeRemoteInterface.PageSession.subscribe(pid, "Page.loadEventFired")
    ChromeRemoteInterface.RPC.Page.navigate(pid, %{url: url}, async: self())

    receive do
      {:chrome_remote_interface, "Page.loadEventFired", _frame_data} ->
        :ok
    after
      timeout -> {:error, :init_timeout}
    end
  end

  @doc """
  Evaluate and return result of JavaScript expression on a given tab

  This function is blocking and will return the result of the expression.
  If the result of the expression is a Promise it will block on
  the promise resolving and return that result.

  ## Example

      Comet.eval(tab_pid, \"""
        MyApp.visit(\#{path}).then((application) => {
          return application.getResponse();
        });
      \""")
  """
  def eval(pid, expression) do
    ChromeRemoteInterface.RPC.Runtime.evaluate(pid, %{
      awaitPromise: true,
      returnByValue: true,
      expression: expression
    })
    |> case do
      {:ok, %{"result" => %{"exceptionDetails" => %{"exception" => %{"className" => name, "description" => description}}}}} -> {:error, {name, description}}
      {:ok, %{"result" => %{"result" => %{"value" => value}, "exceptionDetails" => %{"text" => "Uncaught (in promise)"}}}} -> {:reject, value}
      {:ok, %{"result" => %{"result" => %{"value" => value}}}} -> {:ok, value}
      {:error, %{"error" => %{"message" => message}}} -> {:error, message}
      reason -> {:error, {:unknown, reason}}
    end
  end
end
