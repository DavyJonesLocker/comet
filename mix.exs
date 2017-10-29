defmodule Comet.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :comet,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     source_url: "https://github.com/dockyard/comet",
     docs: [
       extra_section: "RECIPES",
       extras: extras(),
       main: "Comet",
       group_for_extras: group_for_extras(),
       source_ref: "v#{@version}"
     ],
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:chrome_remote_interface, "~> 0.0.6"},
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
