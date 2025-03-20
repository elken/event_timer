defmodule EventTimer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    bot_options = %{
      name: EventTimer,
      consumer: EventTimer.Consumer,
      intents: [:guilds, :guild_messages, :message_content],
      wrapped_token: fn -> System.fetch_env!("BOT_TOKEN") end
    }

    children = [
      EventTimer.Repo,
      {Nostrum.Bot, bot_options}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventTimer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
