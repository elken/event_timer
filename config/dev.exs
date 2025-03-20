config :event_timer, EventTimer.Repo,
  show_sensitive_data_on_connection_error: true,
  log: :debug

config :logger, :console, level: :debug
