defmodule Comet.Mixfile do
  use Mix.Project

  @version "0.1.1"

  def project do
    [app: :comet,
     version: @version,
     elixir: "~> 1.5",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     source_url: "https://github.com/dockyard/comet",
     package: package(),
     description: description(),
     docs: [
       extras: extras(),
       main: "Comet",
       group_for_extras: group_for_extras(),
       source_ref: "v#{@version}"
     ],
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger, :poolboy, :chrome_launcher, :chrome_remote_interface, :plug]]
  end

  defp description(), do: "Quickly render your client side application from your server without the cost of maintaining \"isomorphic JavaScript\"."

  defp package() do
    [
     maintainers: ["Brian Cardarella"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/DockYard/comet"} 
    ]
  end

  defp deps do
    [{:chrome_remote_interface, "~> 0.1.0"},
     {:chrome_launcher, "~> 0.0.4"},
     {:poolboy, "~> 1.5.1"},
     {:plug, "~> 1.0"},
     {:ex_doc, "~> 0.18.1", only: :dev, runtime: false}]
  end

  defp extras() do
    [
      "README.md",
      "recipes/ember.md"
    ]
  end

  defp group_for_extras() do
    [
      "Recipes": ~r/recipes\/.*/
    ]
  end
end
