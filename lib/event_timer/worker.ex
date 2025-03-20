defmodule EventTimer.Worker do
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Cache.Me
  use GenServer
  require Logger

  # Public API

  def start_link(guild) do
    id = Keyword.fetch!(guild, :id)
    GenServer.start_link(__MODULE__, guild, name: worker_name(id))
  end

  def add_event(id, event) do
    GenServer.call(worker_name(id), {:add, event})
  end

  def remove_event(id, code) do
    GenServer.call(worker_name(id), {:rm, code})
  end

  def worker_name(id) do
    :"EventTimer.Worker::#{id}"
  end

  # Server callbacks

  @impl true
  def init(guild) do
    id = Keyword.fetch!(guild, :id)

    Logger.info("Starting worker for #{id}")

    EventTimer.Guilds.get_or_create_guild(to_string(id))

    send(self(), :event_updates)

    {:ok, id}
  end

  # :add

  @impl true
  def handle_call({:add, event}, _from, guild_id) do
    {:ok, _event} =
      EventTimer.Guilds.upsert_event(guild_id, %{
        code: event.code,
        name: event.name,
        date: event.date
      })

    {:reply, upsert_channel(guild_id, event), guild_id}
  end

  # :rm
  @impl true
  def handle_call({:rm, code}, _from, guild_id) do
    {:ok, event} =
      EventTimer.Guilds.get_event(guild_id, code, [:channel])

    {:ok, _channel} =
      Nostrum.Api.Channel.delete(
        String.to_integer(event.channel.id),
        "Deleted timer channel from command."
      )

    {:reply, EventTimer.Guilds.delete_event(guild_id, code), guild_id}
  end

  # :event_updates

  @impl true
  def handle_info(:event_updates, guild_id) do
    Logger.info("Starting work for #{guild_id}")

    {:ok, events} =
      EventTimer.Guilds.get_events(to_string(guild_id))

    case events do
      n when n in [nil, []] ->
        Logger.info("No events to process")

      _ ->
        Logger.info("Processing #{length(events)} events for #{guild_id}")
        Enum.map(events, fn event -> upsert_channel(guild_id, event) end)
    end

    schedule_event_updates()

    {:noreply, guild_id}
  end

  # Private functions

  defp upsert_channel(guild_id, event) do
    {:ok, channel} =
      case EventTimer.Guilds.get_channel(guild_id, event.code) do
        {:ok, nil} -> create_channel(guild_id, event)
        {:ok, channel} -> update_channel(guild_id, channel, event)
      end

    EventTimer.Guilds.update_event(guild_id, %{
      code: event.code,
      channel: channel
    })

    EventTimer.Guilds.get_event(guild_id, event.code, [:channel])
  end

  defp create_channel(guild_id, event) do
    {:ok, guild} = EventTimer.Guilds.get_or_create_guild(to_string(guild_id))

    parent_id =
      case guild do
        %{config: %{parent_id: parent_id}} when not is_nil(parent_id) -> parent_id
        _ -> nil
      end

    Logger.info("No channel found for #{event.code}")

    if parent_id == nil do
      Logger.error("No parent_id set for #{guild_id}")
    end

    {:ok, channel} =
      Nostrum.Api.Channel.create(guild_id,
        name: channel_name(event),
        type: 2,
        permission_overwrites: channel_permissions(guild_id),
        parent_id: parent_id
      )

    EventTimer.Guilds.upsert_channel(guild_id, %{
      id: to_string(channel.id),
      name: channel.name,
      event_code: event.code,
      next_update: next_update()
    })
  end

  defp update_channel(guild_id, channel, event) do
    case Nostrum.Api.Channel.get(String.to_integer(channel.id)) do
      {:ok, _} ->
        if DateTime.compare(channel.next_update, DateTime.utc_now()) == :lt do
          Logger.info("Updating channel #{channel.id} on #{guild_id}")

          {:ok, new_channel} =
            Nostrum.Api.Channel.modify(String.to_integer(channel.id), name: channel_name(event))

          {:ok, updated_channel} =
            EventTimer.Guilds.upsert_channel(guild_id, %{
              id: channel.id,
              name: new_channel.name,
              event_code: event.code,
              next_update: next_update()
            })

          {:ok, updated_channel}
        else
          {:ok, channel}
        end

      _ ->
        EventTimer.Guilds.delete_channel(guild_id, channel.id)
        {:error, :missing}
    end
  end

  defp channel_permissions(guild_id) do
    {:ok, member} = Nostrum.Api.Guild.member(guild_id, Me.get().id)
    {:ok, guild} = GuildCache.get(guild_id)

    {_guild_id, public_role} =
      Enum.find(guild.roles, fn {_id, role} -> role.name == "@everyone" end)

    permission_bit = Nostrum.Permission.to_bit(:connect)

    Enum.reduce(
      member.roles,
      [%{type: 0, deny: permission_bit, id: public_role.id}],
      fn role, acc ->
        [%{type: 0, allow: permission_bit, id: role} | acc]
      end
    )
    |> Enum.reverse()
  end

  defp time_until(date) do
    now = DateTime.utc_now()

    diff_seconds = DateTime.diff(date, now, :second)

    days = div(diff_seconds, 86_400)
    remaining_seconds = rem(diff_seconds, 86_400)

    hours = div(remaining_seconds, 3_600)
    remaining_seconds = rem(remaining_seconds, 3_600)

    minutes = div(remaining_seconds, 60)

    %{days: days, hours: hours, minutes: minutes}
  end

  defp channel_name(%{date: date, code: code}) do
    case DateTime.compare(date, DateTime.utc_now()) do
      :gt ->
        %{days: days, hours: hours, minutes: minutes} = time_until(date)
        "⏲ #{code} || #{days}D #{hours}H #{minutes}M"

      _ ->
        "⏲ #{code} happening!"
    end
  end

  defp next_update do
    DateTime.add(DateTime.utc_now(), 5, :minute)
  end

  defp schedule_event_updates do
    Process.send_after(self(), :event_updates, :timer.minutes(1))
  end
end
