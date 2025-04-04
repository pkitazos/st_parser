defmodule ST.Parser.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/pkitazos/st-parser"

  def project do
    [
      app: :st_parser,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.3"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    A simple, lightweight, flexible parser for Session Types in Elixir.
    Converts textual session type descriptions into typed Elixir
    data structures for protocol verification and implementation.
    """
  end

  defp package do
    [
      name: "st_parser",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
