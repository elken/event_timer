defmodule EventTimer.GuildSupervisor do
  @moduledoc """
  The primary supervisor that manages a guild.

  This spins up when the bot receives a list of all guilds it runs on and for each of these guilds, we spin a worker and pass in the guild ID.

  This is required for database calls and to allow the worker to query data for a specific guild.
  """
  use Supervisor

  require Logger

  def start_link(ids) do
    Supervisor.start_link(__MODULE__, ids, name: __MODULE__)
  end

  @doc """
  Initialize the supervisor with a list of guild IDs.
  """
  @spec init([String.t()]) :: Supervisor.on_start()
  @impl true
  def init(ids) do
    children =
      ids
      |> Enum.map(fn id ->
        %{id: :"#{id}", start: {EventTimer.Worker, :start_link, [[id: id]]}}
      end)

    Logger.info("Started supervisor with #{length(ids)} workers")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
