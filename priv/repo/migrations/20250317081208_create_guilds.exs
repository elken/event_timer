defmodule EventTimer.Repo.Migrations.CreateGuilds do
  use Ecto.Migration

  def up do
    create table(:guilds, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:config, :map)

      timestamps()
    end

    # Create events table with code as primary key
    create table(:events, primary_key: false) do
      add(:code, :string, primary_key: true)
      add(:guild_id, references(:guilds, column: :id, type: :string), null: false)

      add(:name, :string, null: false)
      add(:date, :utc_datetime, null: false)

      timestamps()
    end

    # Create channels table with id as primary key
    create table(:channels, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:guild_id, references(:guilds, column: :id, type: :string), null: false)

      add(:name, :string, null: false)
      add(:next_update, :utc_datetime)

      timestamps()
    end

    alter table("channels") do
      add(:event_code, references(:events, column: :code, type: :string, on_delete: :delete_all),
        null: false
      )
    end

    # Create indexes
    create(index(:events, [:guild_id]))
    create(index(:channels, [:guild_id]))
    create(unique_index(:channels, [:guild_id, :event_code], name: :channels_unique_idx))
    create(unique_index(:events, [:guild_id, :code], name: :events_unique_idx))

    # Enable RLS on all tables
    execute("ALTER TABLE guilds ENABLE ROW LEVEL SECURITY;")
    execute("ALTER TABLE events ENABLE ROW LEVEL SECURITY;")
    execute("ALTER TABLE channels ENABLE ROW LEVEL SECURITY;")

    # Create function for guild context
    execute("""
    CREATE OR REPLACE FUNCTION current_guild_id() RETURNS TEXT AS $$
      SELECT current_setting('app.current_guild_id', TRUE);
    $$ LANGUAGE SQL STABLE;
    """)

    # Create RLS policies
    execute("""
    CREATE POLICY guild_isolation_policy ON guilds
    USING (id = current_guild_id());
    """)

    execute("""
    CREATE POLICY events_isolation_policy ON events
    USING (guild_id = current_guild_id());
    """)

    execute("""
    CREATE POLICY channels_isolation_policy ON channels
    USING (guild_id = current_guild_id());
    """)

    # Force RLS for all users including owner
    execute("ALTER TABLE guilds FORCE ROW LEVEL SECURITY;")
    execute("ALTER TABLE events FORCE ROW LEVEL SECURITY;")
    execute("ALTER TABLE channels FORCE ROW LEVEL SECURITY;")
  end

  def down do
    # Disable RLS
    execute("ALTER TABLE guilds DISABLE ROW LEVEL SECURITY;")
    execute("ALTER TABLE events DISABLE ROW LEVEL SECURITY;")
    execute("ALTER TABLE channels DISABLE ROW LEVEL SECURITY;")

    # Drop policies
    execute("DROP POLICY IF EXISTS guild_isolation_policy ON guilds;")
    execute("DROP POLICY IF EXISTS events_isolation_policy ON events;")
    execute("DROP POLICY IF EXISTS channels_isolation_policy ON channels;")

    # Drop function
    execute("DROP FUNCTION IF EXISTS current_guild_id();")

    # Drop tables
    drop(table(:channels))
    drop(table(:events))
    drop(table(:guilds))
  end
end
