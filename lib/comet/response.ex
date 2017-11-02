defmodule Comet.Response do
  @moduledoc """
  Struct for responses

  This struct is holds the response information from the requests
  to the client applications. All responses will get normalized
  through this struct.

  Defaults:

  * `body` - `""`
  * `headers` - `[{"content-type", "text/html; charset=utf-8"}]`
  * `status` - `200`

  If no an of the default headers are missing from your response those will be
  added in automatically.
  """

  @default_body ""
  @default_headers [{"content-type", "text/html; charset=utf-8"}]
  @default_status 200

  defstruct body: nil, headers: [], status: nil 

  @doc """
  Normalizes different response values into a `Comet.Response` struct

  Currently supported:

  * response is a single `String`, assume its the body.
  * response is a `Map` with `Atom` keys. Attempt to merge into `Comet.Response` struct.
  * response is a `Map` with `String` keys. Convert to `Map` with `Atom` keys and try to normalize again.

  Headers will be normalized into a list of `Tuple`s. Currently supported sources:

  * `List` of `List`s - `[["content-type", "text/html; charset=utf-8"]]` -> `[{"content-type", "text/html; charset=utf-8"}]`
  * `Map` - `%{"content-type" => "text/html; charset=utf-8"}` -> `[{"content-type", "text/html; charset=utf-8"}]`

  This is done to maintain compatbility with `Plug.Conn`.

  An options keyword list of default can be given:

  * `body`
  * `headers` - defaults to `#{inspect(@default_headers)}`
  * `status` - defaults to `#{inspect(@default_status)}`
  """
  def normalize(response, defaults \\ [])
  def normalize({response, defaults}, _ignored), do: normalize(response, defaults)
  def normalize(body, defaults) when is_binary(body) do
    normalize(%{body: body}, defaults)
  end

  def normalize(%{body: body} = response, defaults) when is_binary(body) do
    default_body = Keyword.get(defaults, :body, @default_body)
    default_headers = Keyword.get(defaults, :headers, @default_headers) |> normalize_headers()
    default_status = Keyword.get(defaults, :status, @default_status)

    body = normalize_body(body, default_body)

    headers =
      response
      |> Map.get(:headers, [])
      |> normalize_headers()
      |> concat_default_headers(default_headers)

    status =
      response
      |> Map.get(:status, default_status)
      |> coerce_status()

    struct(__MODULE__, %{body: body, headers: headers, status: status})
  end

  def normalize(%{"body" => body} = response, defaults) when is_binary(body) do
    response
    |> convert()
    |> normalize(defaults)
  end

  defp normalize_body(nil, default_body), do: default_body
  defp normalize_body(body, _default_body), do: body

  defp coerce_status(status) when is_binary(status), do: String.to_integer(status)
  defp coerce_status(status), do: status

  defp convert(response) do
    Enum.reduce(["status", "body", "headers"], %{}, fn(key, new_response) ->
      Map.has_key?(response, key)
      |> case do
        false -> new_response
        true -> Map.put(new_response, String.to_existing_atom(key), Map.get(response, key))
      end
    end)
  end

  defp normalize_headers([]), do: []
  defp normalize_headers(headers) do
    Enum.into(headers, [], fn
      [key, value] -> {String.downcase(key), value}
      {key, value} -> {String.downcase(key), value}
    end)
  end

  defp concat_default_headers(headers, default_headers) do
    headers
    |> filter_default_headers(default_headers)
    |> Enum.concat(headers)
  end

  defp filter_default_headers(headers, default_headers) do
    headers = Enum.into(headers, %{}, &(&1))
    Enum.filter(default_headers, &(!Map.has_key?(headers, elem(&1, 0))))
  end
end