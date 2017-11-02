defmodule Comet.TabWorker do
  @moduledoc """
  Worker macro module for use in your application.

  This module will manage the life cycle and interactions with a browser
  tab worker being managed by `:poolboy`.

  This module cannot be used directly, it should be `use`d in your app:

  ## Example

      defmodule MyApp.TabWorker do
        use Comet.TabWorker
      end

  In your app's config you will have to explicitly define the `module_worker`
  to point to your module:

      config :comet, :supervisor,
        worker_module: MyApp.TabWorker

  Please refer to the public functions documented below.
  Each publicly documented function can be overriden in your
  custom module.

  ## Worker Lifecycle Hooks

  1. `init`
    1. `before_launch/2`
    1. `launch`
      1. `before_navigate/2`
      1. `Comet.navigate_to/2`
      1. `after_navigate/2`
    1. `after_launch/2`

  1. `request/1`
    1. `before_visit/2`
    1. `visit/2`
    1. `after_visit/2`

  1. `after_request/1`
  
  ## Differences beteen `navigate` and `visit`

  ### Navigate

  When launching a tab a URL is provided. This action is referred to a `navigate`

  ### Visit

  The tab will keep your application running. You should use the `visit` functions to manage
  how to route each request to the application.
  """

  Module.add_doc(__MODULE__, 266, :def, {:after_launch, 2}, (quote do: [opts, state]), """
  Run any code after the worker tab launches.

  Default is `noop`. This function is intended to be overridden.

  This lifecycle hook is run only once while the worker is in its `init/1` funtion. It is blocking.

  ## Example

      defmoule MyApp.TabWorker do
        use Comet.TabWorker

        def after_launch(_opts, state) do
          # work

          {:ok, state}
        end
      end

  The return value should be `{:ok, Map}`, if if for any reason an error occurs `{:error, reason}`
  """)

  Module.add_doc(__MODULE__, 265, :def, {:after_navigate, 2}, (quote do: [opts, state]), """
  Run any code after the tab navigation.

  Default is `noop`. This function is intended to be overridden.

  This lifecycle hook is run only once while the worker is in its `init/1` funtion. It is blocking.

  ## Example

      defmoule MyApp.TabWorker do
        use Comet.TabWorker

        def after_navigate(_opts, state) do
          # work

          {:ok, state}
        end
      end

  The return value should be `{:ok, state}`, if if for any reason an error occurs `{:error, reason}`
  """)

  Module.add_doc(__MODULE__, 336, :def, {:after_visit, 2}, (quote do: [state]), """
  Run any code after the visit if changes to the response are desirable.

  Default is `noop`. This function is intended to be overridden.

  This lifecycle hook is run only once while the worker is in its `init/1` funtion. It is blocking.

  ## Example

      defmoule MyApp.TabWorker do
        use Comet.TabWorker

        def after_visit(%Comet.Response{} = response, state) do
          # work

          response
        end
      end

  The return value **must** be a `Comet.Response` struct.
  """)

  Module.add_doc(__MODULE__, 242, :def, {:before_launch, 2}, (quote do: [opts, state]), """
  Run any code before the worker tab launches.

  Default is `noop`. This function is intended to be overridden.

  This lifecycle hook is run only once while the worker is in its `init/1` funtion. It is blocking.

  ## Example

      defmoule MyApp.TabWorker do
        use Comet.TabWorker

        def before_launch(_opts, state) do
          # work

          {:ok, state}
        end
      end

  The return value should be `{:ok, state}`, if if for any reason an error occurs `{:error, reason}`
  """)

  Module.add_doc(__MODULE__, 264, :def, {:before_navigate, 2}, (quote do: [opts, state]), """
  Run any code before the worker tab navigates.

  Default is `noop`. This function is intended to be overridden.

  This lifecycle hook is run only once while the worker is in its `init/1` funtion. It is blocking.

  ## Example

      defmoule MyApp.TabWorker do
        use Comet.TabWorker

        def before_navigate(_opts, state) do
          # work

          {:ok, state}
        end
      end

  The return value should be `{:ok, state}`, if if for any reason an error occurs `{:error, reason}`
  """)

  Module.add_doc(__MODULE__, 335, :def, {:visit, 2}, (quote do: [opts, state]), """
  Hook for triggering a visit action within your application.

  By default this function returns `:not_implemented` and *must* be overridden.

  It is recommended that you use `Comet.eval/2` for running the necessary
  JavaScript in your application to trigger a visit. The visit action within your client application
  should result in a promise. The promise itself should resolve to a JSON object with a `status` and `body` key:
  
  ## Example

      def visit(path, %{pid: pid}) do
        Comet.eval(pid, \"""
          MyApp.visit(\#{path}).then((application) => {
            return application.getResponse();
          });
        \""")
      end

  The default `:not_implemented` return value will result in the worker returning a `%{status: 501: body: "Not Implemented"}` response
  that will be set into the `conn` of `Comet.Plug`.
  """)

  defmacro __using__([]) do
    quote do
      use GenServer

      @init_timeout Application.get_env(:comet, :init_timeout, 2_000)
      @resp_timeout Application.get_env(:comet, :resp_timeout, 1_000)
      @pool :comet_pool

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts)
      end

      def init(:ignore), do: :ignore

      def init(opts) do
        with {:ok, state} <- before_launch(opts, %{}),
             {:ok, state} <- launch(opts, state),
             {:ok, state} <- after_launch(opts, state) do
          {:ok, state}
        else
          {:error, reason} -> {:stop, reason}
          unknown -> {:stop, {:unknown, unknown}}
        end
      end

      def before_launch(_opts, state), do: {:ok, state}

      def launch(opts, state) do
        url = Keyword.get(opts, :launch_url)
        timeout = Keyword.get(opts, :timeout, @init_timeout)

        server = Comet.server(opts)
        {tab, pid} = Comet.new_tab(server)
        Comet.enable(pid)

        state = Map.merge(state, %{server: server, tab: tab, pid: pid})
        {:ok, state} = before_navigate(opts, state)
        
        case Comet.navigate_to(pid, url, timeout) do
          :ok -> after_navigate(opts, state)
          {:error, reason} = error -> error
        end
      end

      def before_navigate(_opts, state), do: {:ok, state}
      def after_navigate(_opts, state), do: {:ok, state}
      def after_launch(_opts, state), do: {:ok, state}

      def handle_call(:pid, _from, %{pid: tab_pid} = state) do
        {:reply, tab_pid, state}
      end

      defp render_template(title, body) do
        """
        <!DOCTYPE html>
        <html>
        <head>
        <title>#{title}</title>
        </head>
        
        <body>
        To retrieve the response from your app you must
        override <code>`Comet.Plug.visit/2`</code>.
        </body>
        
        </html> 
        """
      end

      def handle_call({:request, path}, _from, state) do
        response =
          path
          |> before_visit(state)
          |> visit(state)
          |> case do
            :not_implemented ->
              body = render_template("Not Implemented", """
                To retrieve the response from your app you must
                override <code>`Comet.Plug.visit/2`</code>.
              """)

              %{status: 501, body: body}
            {:ok, response} -> response
            {:reject, response} -> {response, status: 500} 
            {:error, reason} -> %{status: 500, body: render_template("Internal Server Error", "Something went wrong: #{reason}")}
          end
          |> Comet.Response.normalize()
          |> after_visit(state)

        {:reply, response, state}
      end

      def handle_cast(:after_request, state) do
        state = after_request(state)
        :poolboy.checkin(@pool, self())
        {:noreply, state}
      end

      def handle_info(msg, state) do
        {:noreply, state}
      end

      def terminate(reason, %{server: server, tab: tab, pid: pid}) do
        Comet.close_tab(server, tab, pid)

        {:stop, reason}
      end
      def terminate(reason, _state), do: {:stop, reason}

      def before_visit(path, _state), do: path
      def visit(_path, _state), do: :not_implemented
      def after_visit(%Comet.Response{} = response, _state), do: response

      def after_request(state), do: state

      defoverridable [
        before_launch: 2,

        before_navigate: 2,
        after_navigate: 2,

        after_launch: 2,

        before_visit: 2,
        visit: 2,
        after_visit: 2,

        after_request: 1
      ]
    end
  end
end
