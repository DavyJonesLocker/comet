defmodule CometTest.Utils do
  use ExUnit.Case

  test "atomize keys will normalize and atomize all keys in map" do
    result = Comet.Utils.atomize_keys(%{"foo-bar" => "bar", "fooBaz" => "baz", foo_qux: "qux"})
    expected = %{foo_bar: "bar", foo_baz: "baz", foo_qux: "qux"}

    assert result == expected
  end

  test "atomize key will properly normalize key" do
    :foo_bar = Comet.Utils.atomize_key("foo-bar")
    :foo_bar = Comet.Utils.atomize_key("fooBar")
    :foo_bar = Comet.Utils.atomize_key("foo_bar")
    :foo_bar = Comet.Utils.atomize_key(:foo_bar)
  end
end