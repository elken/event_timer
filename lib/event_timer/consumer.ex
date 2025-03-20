defmodule EventTimer.Consumer do
  @behaviour Nostrum.Consumer

  require Logger

  import Nostrum.Struct.Embed

  alias Nostrum.Struct.ApplicationCommand
  alias Supervisor
  alias Nostrum.Api.Interaction
  alias Nostrum.Api.ApplicationCommand

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    data =
      case do_command(interaction) do
        {:embed, embeds} -> %{embeds: embeds}
        _ -> ":white_check_mark:"
      end

    Interaction.create_response(interaction, %{type: 4, data: data})
  end

  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    ids =
      guilds
      |> Enum.map(fn guild -> guild.id end)

    Logger.info("Starting Guild supervisor")

    {:ok, pid} =
      GenServer.start_link(EventTimer.GuildSupervisor, ids, name: EventTimer.GuildSupervisor)

    Logger.info("Guild supervisor started: #{inspect(pid)}")

    Enum.each(ids, &create_guild_commands/1)
  end

  # Ignore any other events
  def handle_event(_), do: :ok

  def create_guild_commands(guild_id) do
    Logger.info("Setting up commands for #{guild_id}")

    add_options = [
      %{type: 3, name: "name", description: "The full name of the event", required: true},
      %{
        type: 3,
        name: "code",
        description: "The short code of the event to use as the identifier",
        required: true
      },
      %{
        type: 4,
        name: "day",
        description: "The day of the month the event occurs (1-31)",
        required: true,
        min_value: 1,
        max_value: 31
      },
      %{
        type: 4,
        name: "month",
        description: "The month of the year the event occurs (1-12)",
        required: true,
        min_value: 1,
        max_value: 12
      },
      %{
        type: 4,
        name: "year",
        description: "The year the event occurs (current year onwards)",
        required: true,
        min_value: DateTime.utc_now().year
      },
      %{
        type: 4,
        name: "hour",
        description: "The hour the event occurs in 24h format (defaults to 0)",
        min_value: 0,
        max_value: 59
      },
      %{
        type: 4,
        name: "minute",
        description: "The minute the event occurs (defaults to 0)",
        min_value: 0,
        max_value: 59
      },
      %{
        type: 4,
        name: "second",
        description: "The second the event occurs (defaults to 0)",
        min_value: 0,
        max_value: 59
      }
    ]

    countdown_options = [
      %{
        type: 1,
        name: "add",
        description:
          "Add a new timer. Using the same shortcode as an existing timer overwrites it.",
        options: add_options
      },
      %{
        type: 1,
        name: "remove",
        description: "Remove an existing timer",
        options: [
          %{
            type: 3,
            name: "code",
            required: true,
            description: "Code of the timer to remove",
            choices: event_choices(guild_id)
          }
        ]
      },
      %{
        type: 1,
        name: "list",
        description: "List all current timers"
      },
      %{
        type: 1,
        name: "set-parent",
        description: "Set the parent category to create channels under",
        options: [
          %{
            type: 7,
            name: "category",
            description: "Category to set as parent",
            required: true,
            channel_types: [4]
          }
        ]
      }
    ]

    ApplicationCommand.create_guild_command(guild_id, %{
      name: "countdown",
      description: "Managing a set of countdown timers through voice channels",
      options: countdown_options
    })
  end

  def do_command(%{
        guild_id: guild_id,
        data: %{name: "countdown", options: [%{name: "set-parent", options: options}]}
      }) do
    options = options_to_list(options)

    case EventTimer.Guilds.update_config(to_string(guild_id), %{
           parent_id: to_string(options.category)
         }) do
      {:ok, _} ->
        embed =
          %Nostrum.Struct.Embed{}
          |> put_title(
            "Parent set to #{%Nostrum.Struct.Channel{id: options.category} |> Nostrum.Struct.Channel.mention()}"
          )
          |> put_color(65280)
          |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))

        {:embed, [embed]}

      {:error, e} ->
        Logger.error("Error setting parent to #{options.category} for #{guild_id}: #{e}")

        embed =
          %Nostrum.Struct.Embed{}
          |> put_title(
            "Error setting parent to #{%Nostrum.Struct.Channel{id: options.category} |> Nostrum.Struct.Channel.mention()} for this guild."
          )
          |> put_color(16_711_680)
          |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))

        {:embed, [embed]}
    end
  end

  def do_command(%{
        guild_id: guild_id,
        data: %{name: "countdown", options: [%{name: "add", options: options}]}
      }) do
    options = options_to_list(options)
    hour = Map.get(options, :hour, 0)
    minute = Map.get(options, :minute, 0)
    second = Map.get(options, :second, 0)

    {:ok, date} =
      case NaiveDateTime.new(options.year, options.month, options.day, hour, minute, second) do
        {:ok, date} -> DateTime.from_naive(date, "Etc/UTC")
        {:error, reason} -> {:error, "Invalid date: #{reason}"}
      end

    event = %{
      name: options.name,
      code: options.code,
      date: date
    }

    {:ok, event} =
      EventTimer.Worker.add_event(guild_id, event)

    create_guild_commands(guild_id)

    {:embed,
     [
       event_embed(event)
     ]}
  end

  def do_command(%{
        guild_id: guild_id,
        data: %{name: "countdown", options: [%{name: "remove", options: options}]}
      }) do
    options = options_to_list(options)

    embed =
      case EventTimer.Guilds.get_event(guild_id, options.code) do
        {:error, :not_found} ->
          %Nostrum.Struct.Embed{}
          |> put_title("No event found for #{options.code}")
          |> put_color(16_711_680)
          |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))

        _ ->
          EventTimer.Worker.remove_event(guild_id, options.code)
          create_guild_commands(guild_id)

          %Nostrum.Struct.Embed{}
          |> put_title("Removed event for '#{options.code}'")
          |> put_color(65280)
          |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))
      end

    {:embed, [embed]}
  end

  def do_command(%{guild_id: guild_id, data: %{name: "countdown", options: [%{name: "list"}]}}) do
    {:embed, event_embeds(guild_id)}
  end

  defp event_embed_fields(event) do
    date = Calendar.strftime(event.date, "%d/%m/%y %I:%M:%S %p")

    %Nostrum.Struct.Embed.Field{
      name: "#{event.name} (#{event.code}) expiring at #{date}",
      value: Nostrum.Struct.Channel.mention(%Nostrum.Struct.Channel{id: event.channel.id})
    }
  end

  defp event_embed(event) do
    %Nostrum.Struct.Embed{}
    |> put_title(event.name)
    |> put_description(event.code)
    |> put_timestamp(event.date)
    |> put_field(
      "Channel",
      Nostrum.Struct.Channel.mention(%Nostrum.Struct.Channel{id: event.channel.id})
    )
  end

  defp event_embeds(guild_id) do
    {:ok, events} =
      EventTimer.Guilds.get_events(guild_id)

    case events do
      [] ->
        [
          %Nostrum.Struct.Embed{}
          |> put_title("No events added yet")
          |> put_description("Add some events to see something useful here instead.")
          |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))
          |> put_color(16_711_680)
        ]

      _ ->
        [
          %Nostrum.Struct.Embed{
            title: "Current Events",
            description: "The current list of ongoing events and their channels",
            timestamp: DateTime.to_iso8601(DateTime.utc_now()),
            color: 65280,
            fields: Enum.map(events, &event_embed_fields/1)
          }
        ]
    end
  end

  defp event_choices(guild_id) do
    {:ok, events} =
      EventTimer.Guilds.get_events(to_string(guild_id))

    case events do
      n when n in [nil, []] ->
        []

      _ ->
        Enum.reduce(events, [], fn event, acc ->
          [%{name: event.name, value: event.code} | acc]
        end)
    end
  end

  defp options_to_list(options) do
    Enum.reduce(options, %{}, fn option, acc ->
      Map.put(acc, String.to_atom(option.name), option.value)
    end)
  end
end
