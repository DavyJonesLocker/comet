defmodule Comet.Cache do
  @moduledoc """
  Behaviour cache primitives required by Comet.

  This module serves only as a `@behaviour` for other Cache modules.

  If you decide to provide your own custom Cache you should use the `@behaviour` provided
  by this module. You **must** define `get/1` and `insert/2` as required by the behaviour:

  ## Example

      defmodule MyApp.CustomCache do
        @behaviour Comet.Cache

        def get(key) do
          ...
        end

        def insert(key, value) do
          ...
        end
      end
  """

  @callback get(path :: String) :: %Comet.Response{body: String, headers: List, status: Integer}
  @callback insert(path :: String, response :: %Comet.Response{body: String, headers: List, status: Integer}) :: term
end