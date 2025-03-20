defmodule EventTimer.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_timer,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx, :observer, :runtime_tools],
      mod: {EventTimer.Application, []}
    ]
  end

  defp aliases do
    [
      setup: ["ecto.create", "ecto.migrate"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, github: "Kraigie/nostrum"},
      {:exsync, "~> 0.4", only: :dev},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"}
    ]
  end
end
