defmodule CometTest.Response do
  use ExUnit.Case

  test "can normalize a string response into the struct" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 200}
    ^expected = Comet.Response.normalize("foobar")
  end

  test "can normalize a map with atom keys into the struct" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201})
  end

  test "can normalize a map with string keys into the struct" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{"body" => "foobar", "headers" => [{"content-type", "text/html; charset=utf-8"}], "status" => 201})
  end

  test "can normalize a map with some string keys into the struct" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{"body" => "foobar", "otherheaders" => [{"content-type", "application/json; charset=utf-8"}], "status" => 201})
  end

  test "can normalze a list of lists headers into a list of tuples" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{"body" => "foobar", "headers" => [["content-type", "text/html; charset=utf-8"]], "status" => 201})
  end

  test "can normalze a headers keys" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{"body" => "foobar", "headers" => [{"Content-Type", "text/html; charset=utf-8"}], "status" => 201})
  end

  test "can normalze a map headers into a list of tuples" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{"body" => "foobar", "headers" => %{"content-type" => "text/html; charset=utf-8"}, "status" => 201})
  end

  test "headers should always include content-type" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}, {"age", "12"}], status: 201}
    ^expected = Comet.Response.normalize(%{body: "foobar", headers: [{"age", "12"}], status: 201})
  end

  test "status is coerced from string to integer" do
    expected = %Comet.Response{body: "foobar", headers: [{"content-type", "text/html; charset=utf-8"}], status: 201}
    ^expected = Comet.Response.normalize(%{body: "foobar", status: "201"})
  end
end