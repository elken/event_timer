defmodule EventTimer.Guilds do
  @moduledoc """
  Ecto repo methods for the app.
  """
  require Logger

  import Ecto.Query

  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Channel
  alias EventTimer.Repo
  alias EventTimer.Guild
  alias EventTimer.Event
  alias EventTimer.Channel
  alias EventTimer.GuildContext

  # Guild operations

  @doc """
  Get or create a guild.

  It's important that we ensure a guild is always available.
  """
  @spec get_or_create_guild(String.t() | integer(), map(), [atom()]) :: EventTimer.Guild.t()
  def get_or_create_guild(guild_id, attrs \\ %{}, preloads \\ [:events, :channels]) do
    GuildContext.with_guild(guild_id, fn ->
      guild =
        case Repo.get(Guild, guild_id) do
          nil ->
            attrs = Map.merge(%{id: guild_id}, attrs)

            guild =
              %Guild{}
              |> Guild.changeset(attrs)
              |> Repo.insert()

            case guild do
              {:ok, guild} -> guild
              {:error, e} -> Logger.error("Error creating guild: #{e}")
            end

          guild ->
            guild
        end

      EventTimer.Repo.preload(guild, preloads)
    end)
  end

  @doc """
  Update the configuration for a guild.
  """
  @spec update_config(String.t() | integer(), map(), [atom()]) :: EventTimer.Guild.t()
  def update_config(guild_id, config, preloads \\ [:events, :channels]) do
    GuildContext.with_guild(guild_id, fn ->
      guild =
        case Repo.get(Guild, guild_id) do
          nil ->
            {:error, :not_found}

          guild ->
            config_params = %{id: to_string(guild_id), config: config}

            guild =
              guild
              |> Guild.changeset(config_params)
              |> Repo.update()

            case guild do
              {:ok, guild} -> guild
              {:error, e} -> Logger.error("Error updating config: #{e}")
            end
        end

      EventTimer.Repo.preload(guild, preloads)
    end)
  end

  # Event operations
  @doc """
  Get all events for a specific guild with the channel preloaded
  """
  @spec get_events(String.t() | integer()) :: [EventTimer.Event.t()]
  def get_events(guild_id) do
    GuildContext.with_guild(guild_id, fn ->
      Event
      |> where(guild_id: ^to_string(guild_id))
      |> preload([:channel])
      |> Repo.all()
    end)
  end

  @doc """
  Get an event from a guild by the code with an optional list of preloads.
  """
  @spec get_event(String.t() | integer(), String.t(), [atom()]) :: EventTimer.Event.t()
  def get_event(guild_id, code, preloads \\ []) do
    GuildContext.with_guild(guild_id, fn ->
      Repo.get_by(Event, code: code, guild_id: to_string(guild_id))
      |> EventTimer.Repo.preload(preloads)
    end)
  end

  @doc """
  Specifically update an event.

  Ideally we would just prefer using upserts, but it's
  awkward to only upsert a single field. As such, this
  is only used to update the channel_id when we have
  a channel object ready.
  """
  @spec update_event(String.t() | integer(), map()) :: EventTimer.Event.t()
  def update_event(guild_id, attrs) do
    GuildContext.with_guild(guild_id, fn ->
      Repo.get_by!(Event, code: attrs.code, guild_id: to_string(guild_id))
      |> EventTimer.Repo.preload([:channel])
      |> Ecto.Changeset.change(attrs)
      |> Repo.update!()
    end)
  end

  @doc """
  Attempt to insert a new event, if one already exists then update it instead.

  If you setup a new timer for the same code, it should overwrite the old one and just update the channel name etc.
  """
  @spec upsert_event(String.t() | integer(), map()) :: EventTimer.Event.t()
  def upsert_event(guild_id, attrs) do
    GuildContext.with_guild(guild_id, fn ->
      %Event{}
      |> Event.changeset(Map.put(attrs, :guild_id, to_string(guild_id)))
      |> Repo.insert!(
        on_conflict: {:replace, [:code, :name, :date]},
        conflict_target: [:guild_id, :code]
      )
    end)
  end

  @doc """
  Delete an event for a guild by code.
  """
  @spec delete_event(String.t() | integer(), String.t()) :: EventTimer.Event.t()
  def delete_event(guild_id, code) do
    GuildContext.with_guild(guild_id, fn ->
      case Repo.get_by(Event, code: code, guild_id: to_string(guild_id)) do
        nil -> {:error, :not_found}
        event -> Repo.delete(event)
      end
    end)
  end

  # Channel operations

  # Event operations
  @doc """
  Get all channels for a specific guild
  """
  @spec get_channels(String.t() | integer()) :: [EventTimer.Channel.t()]
  def get_channels(guild_id) do
    GuildContext.with_guild(guild_id, fn ->
      Channel
      |> where(guild_id: ^guild_id)
      |> Repo.all()
    end)
  end

  @doc """
  Get a channel from a guild by the event code.
  """
  @spec get_channel(String.t() | integer(), String.t()) :: EventTimer.Channel.t()
  def get_channel(guild_id, code) do
    GuildContext.with_guild(guild_id, fn ->
      Repo.get_by(Channel, event_code: code, guild_id: to_string(guild_id))
      |> EventTimer.Repo.preload([:event])
    end)
  end

  @doc """
  Attempt to insert a new channel, if one already exists then update it instead.
  """
  @spec upsert_channel(String.t() | integer(), map()) :: EventTimer.Channel.t()
  def upsert_channel(guild_id, attrs) do
    GuildContext.with_guild(guild_id, fn ->
      %Channel{}
      |> Channel.changeset(Map.put(attrs, :guild_id, to_string(guild_id)))
      |> Repo.insert!(
        on_conflict: {:replace, [:id, :name, :next_update]},
        conflict_target: [:guild_id, :event_code]
      )
    end)
  end

  @doc """
  Delete a channel for a guild by Discord API ID.
  """
  @spec delete_event(String.t() | integer(), String.t()) :: EventTimer.Channel.t()
  def delete_channel(guild_id, id) do
    GuildContext.with_guild(guild_id, fn ->
      case Repo.get_by(Channel, id: id, guild_id: to_string(guild_id)) do
        nil -> {:error, :not_found}
        channel -> Repo.delete(channel)
      end
    end)
  end
end
