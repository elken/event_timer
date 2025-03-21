defmodule EventTimer.Guild do
  @moduledoc """
  The top-most entity, most commonly called a "Server".

  Mostly for our purposes it's just a link to events and channels, with a way to store server-specific configuration.
  """
  @type t() :: EventTimer.Guild
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, EventTimer.IdType, []}
  @foreign_key_type EventTimer.IdType
  schema "guilds" do
    has_many(:events, EventTimer.Event, foreign_key: :guild_id)
    has_many(:channels, EventTimer.Channel, foreign_key: :guild_id)

    embeds_one :config, Config, on_replace: :update do
      field(:parent_id, :string)
    end

    timestamps()
  end

  def changeset(guild, attrs) do
    guild
    |> cast(attrs, [:id])
    |> cast_embed(:config, with: &config_changeset/2)
    |> validate_required([:id])
    |> unique_constraint(:id)
  end

  def config_changeset(config, attrs \\ %{}) do
    config
    |> cast(attrs, [:parent_id])
  end
end
