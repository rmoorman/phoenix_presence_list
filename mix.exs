defmodule PhoenixPresenceList.MixProject do
  use Mix.Project

  @version "0.1.1"

  @description """
  Keep a presence list up to date using broadcasted presence_diff data.
  """

  def project() do
    [
      app: :phoenix_presence_list,
      version: @version,
      elixir: "~> 1.7",
      deps: deps(),
      description: @description,
      package: package(),
      source_url: "https://github.com/rmoorman/phoenix_presence_list"
    ]
  end

  def application() do
    [
      applications: []
    ]
  end

  defp deps() do
    [
      {:phoenix, "~> 1.4.0", only: :test},
      {:phoenix_pubsub, "~> 1.1", only: :test},
      {:mix_test_watch, "~> 0.8", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/rmoorman/phoenix_presence_list"}
    ]
  end
end
