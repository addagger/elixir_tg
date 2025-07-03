defmodule Tg.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_tg,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},
      {:bandit, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
  
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
