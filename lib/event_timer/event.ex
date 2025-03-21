defmodule EventTimer.Event do
  @moduledoc """
  A model to represent an Event.

  There is potential down the line to integrate with
  Discord's Events API but for now it's kept simple
  """
  @type t() :: EventTimer.Event

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:code, :string, []}
  @foreign_key_type :string
  schema "events" do
    field(:name, :string)
    field(:date, :utc_datetime)

    belongs_to(:guild, EventTimer.Guild)

    has_one(:channel, EventTimer.Channel)

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:code, :guild_id, :name, :date])
    |> validate_required([:code, :guild_id, :name, :date])
    |> foreign_key_constraint(:guild_id)
  end
end
