defmodule EventTimer.Guilds do
  @moduledoc """
  Context module for guild data operations.
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

  def get_events(guild_id) do
    GuildContext.with_guild(guild_id, fn ->
      Event
      |> where(guild_id: ^to_string(guild_id))
      |> preload([:channel])
      |> Repo.all()
    end)
  end

  def get_event(guild_id, code, preloads \\ []) do
    GuildContext.with_guild(guild_id, fn ->
      Repo.get_by(Event, code: code, guild_id: to_string(guild_id))
      |> EventTimer.Repo.preload(preloads)
    end)
  end

  def update_event(guild_id, attrs) do
    GuildContext.with_guild(guild_id, fn ->
      Repo.get_by!(Event, code: attrs.code, guild_id: to_string(guild_id))
      |> EventTimer.Repo.preload([:channel])
      |> Ecto.Changeset.change(attrs)
      |> Repo.update!()
    end)
  end

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

  def delete_event(guild_id, code) do
    GuildContext.with_guild(guild_id, fn ->
      case Repo.get_by(Event, code: code, guild_id: to_string(guild_id)) do
        nil -> {:error, :not_found}
        event -> Repo.delete(event)
      end
    end)
  end

  # Channel operations

  def get_channels(guild_id) do
    GuildContext.with_guild(guild_id, fn ->
      Channel
      |> where(guild_id: ^guild_id)
      |> Repo.all()
    end)
  end

  def get_channel(guild_id, code) do
    GuildContext.with_guild(guild_id, fn ->
      Repo.get_by(Channel, event_code: code, guild_id: to_string(guild_id))
      |> EventTimer.Repo.preload([:event])
    end)
  end

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

  def delete_channel(guild_id, id) do
    GuildContext.with_guild(guild_id, fn ->
      case Repo.get_by(Channel, id: id, guild_id: to_string(guild_id)) do
        nil -> {:error, :not_found}
        channel -> Repo.delete(channel)
      end
    end)
  end
end
