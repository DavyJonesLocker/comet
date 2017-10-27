# Ember Recipes

There are two ways we can render our app, depending upon how your Ember app is written.

## Safe, clean, but slowest

You can reproduce something similar to what Fastboot does and use the Application factor's `visit` API.

This has the advantage of absolutely ensuring that the application state is completely reset. You tear down and
reboot everything on each request. However, it comes with an added cost of blocking on that app boot time
for each request. Depending upon your app's specific needs this may be the safest option so let's see how to implement it:

First, to make things easiest you should enable your Application's global to be available in all environments. You can
do so by setting the `ember-export-application-global` settings:

```js
// config/environment.js

module.exports = function(environment) {
  var ENV = {
    // other configuration
    exportApplicationGlobal: 'MyApp'
  }
};
```

This will make your Application's factory available during all environments. You may want to read more about
[ember-export-application-global](https://github.com/ember-cli/ember-export-application-global) to decide
if this is what you want to do. If not then you should consider the next option that requires a bit more setup.

Next, in your `TabWorker` module you will want to override the `visit/2` function:

```elixir
def visit(path, %{pid: pid}) do
  Comet.promise_eval(pid, """
    MyApp.visit(#{path}).then((application) => {
      let status = application.getStatus() || 200;
      // `application.getStatus` doesn't actually exist
      // it is just a placeholder for your own custom implementation
      let body = document.documentElement.outerHTML;
      return {status, body};
    });
  """)
end
```

Comet will handle the rest. As long as you are setting the proper status code and body.

If the promise rejects for any reason Comet will handle that as well and respond with a `500`.

## Safe, complex, but slow

If you do not want to expose the Application global in production you can set up a listener for the Application factory.
When that event triggers, we can cache the Application global on `window` for use. This code will only run in our Chrome tab
instance and will not run for regular visitors.

In your `TabWorker` you will need to override the `before_navigate` function:

```elixir
def before_navigate(_opts, %{pid: pid} = state) do
  ChromeRemoteInterface.RPC.Page.addScriptToEvaluateOnLoad(pid, %{ scriptSource: """
    window.addEventListener('application', ({ detail }) => {
      window.__application__ = detail;
    });
  """})

  {:ok, state}
end
```

Now you can override the `visit` function to use `window.__application`

```js
def visit(path, %{pid: pid}) do
  Comet.promise_eval(pid, """
    window.__application__.visit(#{path}).then((application) => {
      let status = application.getStatus() || 200;
      // `application.getStatus` doesn't actually exist
      // it is just a placeholder for your own custom implementation
      let body = document.documentElement.outerHTML;
      return {status, body};
    });
  """)
end
```

## Complex but fast

The last option available is to work around the Application factory. We can do this
with the following steps:

1. We listen for the `application` event
1. We get the Application factory
1. When we setup an `after_navigate` function
1. `after_navigate` will pre-boot our Ember app and leave it in a unvisited state
1. When a request comes in, we grab the pre-booted app and trigger a visit
1. The resulting promise from that visit renders the response object
1. In an `GenServer.cast/2` call we toss the application instance, pre-boot a new instance, cache it, and release the tab worker back to the pool

This method has some peformance benefits. Primarily it side-steps the need to re-run the application initializers as well as the instance initializers on each request.
When a new request comes in you should have a freshly booted application, just one that has not triggered any `visit` yet. In theory the application should be
in a "clean" state. However, this depends upon how you wrote your app. The application's initializers will only be run once, when the tab
first navigates to the app. After each request a new instance is created so the instance initializers are re-run, but we don't incur this cost
on each request beacuse we are preparing the instance for the next request. Let's set this up:

Let's see a complete `TabWorker` solution that you could implement:

```elixir
defmodule MyApp.TabWorker do
  use Comet.TabWorker

  @pool :comet_pool

  # We first want to set up a new promise around the listen event for `application`
  def before_navigate(_opts, %{pid: pid} = state) do
    ChromeRemoteInterface.RPC.Page.addScriptToEvaluateOnLoad(pid, %{ scriptSource: """
      window.applicationPromise = new Promise((resolve) => {
        window.addEventListener('application', ({ detail }) => {
          resolve(detail);
        });
      });
    """})

    {:ok, state}
  end

  # Next we need to set up an `after_navigate` function.
  # This function will trigger after the initial `navigate` life cycle hook for the tab. We can re-use
  # this function after each `visit`:
  def after_navigate(_opts, %{pid: pid} = state) do
    Comet.promise_eval(pid, """
      window.applicationPromise.then((Application) => {
        return Application.boot().then(() => {
          let instance = Application.buildInstance();
          window.__app_instance__ = instance;
          return instance.boot();
        });
      });
    """)

    {:ok, state}
  end

  # By default the TabWorker will checkin the worker within this function.
  # However, we don't want that behavior in this case. We want to wait until
  # We have torn down the current application instance and created
  # a new one. So we re-use `after_navigate/2` here to do that.
  def after_visit(opts, state) do
    {:ok, state} = after_navigate(opts, state)
    {:noreply, state}
  end

  # The overridden `handle_info` will listen for the result of the promise eval
  # from `after_navigate`. Once that resolves we know the tab is now
  # in a state that it has a clean application instance booted and can
  # now receive requests. So we can return this worker back to the pool
  def handle_info({:chrome_remote_interface, "Runtime.evaluate", _result}, state) do
    :poolboy.checkin(@pool, self())

    {:noreply, state}
  end

  # Because we overrode `handle_info/2` we should add back the catch-all
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
```