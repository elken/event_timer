defmodule EventTimer.GuildContext do
  require Logger

  def with_guild(guild_id, fun) do
    guild_id = to_string(guild_id)

    EventTimer.Repo.transaction(fn ->
      try do
        EventTimer.Repo.query!("SET LOCAL app.current_guild_id = '#{guild_id}'")

        fun.()
      rescue
        e ->
          Logger.error("Error running function with guild #{guild_id}: #{inspect(e)}")
          reraise e, __STACKTRACE__
      catch
        kind, reason ->
          Logger.error("Caught #{kind} with reason: #{inspect(reason)} for guild #{guild_id}")
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end)
  end
end
