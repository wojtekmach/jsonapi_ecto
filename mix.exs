defmodule GitHub.Ecto.Mixfile do
  use Mix.Project

  def project do
    [app: :jsonapi_ecto,
     version: "0.0.1",
     description: "Ecto adapter for any JSON API compatible backend",
     package: package,
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ecto, :httpoison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ecto, "~> 2.0.0-beta"},
      {:httpoison, "~> 0.8.0"},
      {:poison, "~> 2.0"},
    ]
  end

  defp package do
    [
      maintainers: ["Wojtek Mach"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/wojtekmach/json_api_ecto"},
    ]
  end
end
