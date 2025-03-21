defmodule EventTimer.Consumer do
  @moduledoc """
  The main entry point for our bot.

  Handles all the commands and interactions with the various GenServers we have around.

  Nostrum defines the `handle_event/1` handlers as multiple clauses so you will have to check the code for documentation of each one.
  """
  @behaviour Nostrum.Consumer

  require Logger

  import Nostrum.Struct.Embed

  alias Nostrum.Struct.ApplicationCommand
  alias Supervisor
  alias Nostrum.Api.Interaction
  alias Nostrum.Api.ApplicationCommand

  @doc """
  Handler for getting a new interaction (application command call).

  The other various commands that are called from this typically return embeds.
  """
  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    result =
      case interaction do
        %{data: %{name: "countdown", options: [%{name: "set-parent"}]}} -> set_parent(interaction)
        %{data: %{name: "countdown", options: [%{name: "add"}]}} -> add_event(interaction)
        %{data: %{name: "countdown", options: [%{name: "remove"}]}} -> remove_event(interaction)
        %{data: %{name: "countdown", options: [%{name: "list"}]}} -> list_events(interaction)
        _ ->
          embed =
            %Nostrum.Struct.Embed{}
            |> put_title("How did you trigger this?")
            |> put_color(16_711_680)
            |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))

        {:embed, [embed]}
      end

    data =
      case result do
        {:embed, embeds} -> %{embeds: embeds}
        _ -> ":white_check_mark:"
      end

    Interaction.create_response(interaction, %{type: 4, data: data})
  end

  @impl true
  def handle_event({:READY, %{guilds: guilds}, _ws_state}) do
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

  @doc """
  Create the various Guild commands we use.

  For the sake of simplicity also, the remove command gets a list of all the valid events it can delete.
  """
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

  @doc """
  Handle `/countdown set-parent`

  Expects a category channel and sets the parent based on that.
  """
  @spec set_parent(Nostrum.Struct.Interaction.t()) :: {:embed, [Nostrum.Struct.Embed.t()]}
  def set_parent(%{
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

  @doc """
  Handle `/countdown add`

  Add a new event based on the options we pass in, create a new event and return an embed showing the relevant info.

  We also update the guild commands here so that `/countdown remove` has a list of choices available.
  """
  @spec add_event(Nostrum.Struct.Interaction.t()) :: {:embed, [Nostrum.Struct.Embed.t()]}
  def add_event(%{
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
       %Nostrum.Struct.Embed{}
       |> put_title(event.name)
       |> put_description(event.code)
       |> put_timestamp(event.date)
       |> put_field(
         "Channel",
         Nostrum.Struct.Channel.mention(%Nostrum.Struct.Channel{id: event.channel.id})
       )
     ]}
  end

  @doc """
  Handle `/countdown remove`

  Attempt to remove an event if it exists, otherwise return an error embed.

  We also update the commands here so that `/countdown remove` has an up-to-date listing.
  """
  @spec remove_event(Nostrum.Struct.Interaction.t()) :: {:embed, [Nostrum.Struct.Embed.t()]}
  def remove_event(%{
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

  @doc """
  Handle `/countdown list`

  Get an embed with all the channels in it. The Discord limit for embeds is 10, and the max limit of fields is 25; but I'm not banking on many others using this so I'm fine with the 25 default.
  """
  @spec list_events(Nostrum.Struct.Interaction.t()) :: {:embed, [Nostrum.Struct.Embed.t()]}
  def list_events(%{guild_id: guild_id, data: %{name: "countdown", options: [%{name: "list"}]}}) do
    {:embed, guild_embed(guild_id)}
  end

  @spec event_embed_field(EventTimer.Event.t()) :: Nostrum.Struct.Embed.Field.t()
  defp event_embed_field(event) do
    date = Calendar.strftime(event.date, "%d/%m/%y %I:%M:%S %p")

    %Nostrum.Struct.Embed.Field{
      name: "#{event.name} (#{event.code}) expiring at #{date}",
      value: Nostrum.Struct.Channel.mention(%Nostrum.Struct.Channel{id: event.channel.id})
    }
  end

  @spec guild_embed(String.t() | integer()) :: [Nostrum.Struct.Embed.t()]
  defp guild_embed(guild_id) do
    {:ok, events} =
      EventTimer.Guilds.get_events(guild_id)

    [
      case events do
        [] ->
          %Nostrum.Struct.Embed{}
          |> put_title("No events added yet")
          |> put_description("Add some events to see something useful here instead.")
          |> put_timestamp(DateTime.to_iso8601(DateTime.utc_now()))
          |> put_color(16_711_680)

        _ ->
          %Nostrum.Struct.Embed{
            title: "Current Events",
            description: "The current list of ongoing events and their channels",
            timestamp: DateTime.to_iso8601(DateTime.utc_now()),
            color: 65280,
            fields: Enum.map(events, &event_embed_field/1)
          }
      end
    ]
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
