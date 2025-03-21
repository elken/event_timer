defmodule EventTimer.Channel do
  @moduledoc """
  A representation of a Discord Channel.

  We also cache when the next update should occur, in an attempt to work around Discord's frankly unfair rate limits.
  """
  @type t() :: EventTimer.Channel

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  @foreign_key_type :string
  schema "channels" do
    field(:name, :string)
    field(:next_update, :utc_datetime)

    belongs_to(:guild, EventTimer.Guild)

    belongs_to(:event, EventTimer.Event,
      foreign_key: :event_code,
      references: :code
    )

    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:id, :guild_id, :event_code, :name, :next_update])
    |> validate_required([:id, :guild_id, :event_code, :name])
    |> foreign_key_constraint(:guild_id)
  end
end
