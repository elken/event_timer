import Config

config :event_timer, ecto_repos: [EventTimer.Repo]

config :event_timer, EventTimer.Repo,
  database: "event_timer_#{config_env()}",
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  hostname: System.fetch_env!("DB_HOSTNAME"),
  pool_size: 10

config :logger, :console,
  metadata: [:bot, :shard, :guild, :channel],
  format: "$time $metadata[$level] $message\n"

# Ignore Emacs temp files
config :exsync, exclusions: [~r/#/]
