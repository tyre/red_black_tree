defmodule RedBlackTree.Mixfile do
  use Mix.Project

  def project do
    [app: :red_black_tree,
     version: "1.0",
     source_url: "https://github.com/SenecaSystems/red_black_tree",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package]
  end

  def application do
    [applications: [:logger]]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Seneca Systems"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/SenecaSystems/red_black_tree"}
    ]
  end

  defp deps do
    []
  end
end
