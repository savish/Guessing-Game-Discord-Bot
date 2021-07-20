# Guessing Game Discord Bot

Play a simple guessing game in your discord server by adding this bot. Use `!help` for commands.

## Installation

To get the source onto the target machine, do:

1. `git clone...`
2. `cd <<workdir>>`
3. `mix deps.get`

To prepare the bot for usage, you need to specify a discord bot token (you can get one from the discord developer portal). You can do this directly in the `config.exs` file, or in env specific config files. The second case looks like (from the `<<workdir>>` above):

1. `cd config`
2. `cp test.exs dev.exs`
3. Replace the token placeholder in `dev.exs` with a valid bot token

Once done, you can launch the bot on your local dev machine using:

```elixir
iex -S mix
```

For testing, simply replace the bot token palceholder in `test.exs` with a valid bot token as well. However, since this is structured as an umbrella app, you can test the 'game' part of the app, without touching the 'bot' part by running the tests from the `guessing_game` app folder instead. From `<<workdir>>` do:

1. `cd apps/guessing_game`
2. `mix test`

Doing this does not require you to udpate the `test.exs` file with a valid discord bot token.

Instructions for adding a bot to your server can be found on the discord [developer portal](https://discord.com/developers/docs) as well.
