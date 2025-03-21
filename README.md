# Event Timer

A Discord bot for managing countdowns for events (not Discord's
events, naming is hard...)

## Setup

Setting the bot up is pretty straightforward, thankfully the bot needs very few permissions.

1. Create a new bot
2. Record its secret for the token below
3. On the Settings sidebar, go to "OAuth2"
4. Check the following scopes and copy the generated URL
    - `bot`
    - `applications.commands`
    - `bot -> Manage Channels`
5. Navigate to the generated URL and select whichever server you own you want to add the bot to

## Usage

All that's needed is to setup the bot on the code side is the
following environment variables:

### `BOT_TOKEN`

The secret token generated from the Discord Developer portal. As per
their recommendations, make sure you store this safely.

### `DB_USER`

The username used to connect to the database

### `DB_PASSWORD`

The password used to connect to the database

### `DB_HOSTNAME`

The hostname of the database to connect to

Then run the bot either with `iex -S mix` or build a production
release and run there

```sh
MIX_ENV=prod mix release
```

And follow the instructions it generates.

After startup, assuming all the permissions are configured you should
be able to use the commands without issue.

## Commands

The bot makes available the following guild commands:

### `/countdown set-parent`

This sets the parent category under which the timers get created, by
default they'll just end up in the global list.

If you try and create a channel without a parent, you'll get an error logged.

### `/countdown add`

This adds a new event to keep track of. Follow the required arguments to add.

### `/countdown remove`

This removes an event. Follow the required arguments to add. Should be pre-populated with all current timers.

### `/countdown list`

List all currently running timers
