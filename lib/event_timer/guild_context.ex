defmodule EventTimer.GuildContext do
  @moduledoc """
  Context object for a Guild.

  Data in the database has been protected with Row-Level Security (RLS) with the policy defined as needing to match `app.current_guild_id` (check the `create_guilds` migration).

  As such, we have to use this context object to wrap a transaction and ensure that a guild can only ever get the data for itself.
  """
  require Logger

  @doc """
  As per the module doc, we have to wrap database calls with this helper to ensure that we properly set the guild ID for RLS.
  """
  @spec with_guild(String.t() | integer(), function()) :: any()
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
