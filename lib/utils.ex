defmodule Comet.Utils do
  def atomize_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn({key, value}) -> {atomize_key(key), value} end)
  end
  def atomize_keys(other), do: other

  def atomize_key(key) when is_binary(key) do
    key
    |> String.replace("-", "_")
    |> Macro.underscore()
    |> String.to_atom()
  end
  def atomize_key(key) when is_atom(key), do: key
end