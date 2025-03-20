defmodule EventTimer.Repo do
  use Ecto.Repo,
    otp_app: :event_timer,
    adapter: Ecto.Adapters.Postgres
end
