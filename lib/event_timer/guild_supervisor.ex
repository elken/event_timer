defmodule EventTimer.GuildSupervisor do
  use Supervisor

  require Logger

  def start_link(ids) do
    Supervisor.start_link(__MODULE__, ids, name: __MODULE__)
  end

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
