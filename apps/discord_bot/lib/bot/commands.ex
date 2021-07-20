defmodule Bot.Commands do
  use Alchemy.Cogs
  import Alchemy.Embed
  alias Alchemy.Embed
  alias Bot.Execute, as: Exec

  Cogs.def help() do
    %Embed{}
    |> title("Guessing Game Discord Bot")
    |> author(name: "GenKali", url: "https://gitlab.com/savish")
    |> color(0xADD8E6)
    |> description("Guess the number that is assigned to you and score points based on how
      close you get. Prove that you are the better oracle! And keep an eye out for special
      bonuses...")
    |> field("Start...", "Join a hosted game", inline: true)
    |> field("Play...", "Guess your number!", inline: true)
    |> field("Win!", "Top score at the end wins!", inline: true)
    |> field("Commands", "
    - `!host` host a game setting you as the host
    - `!join ?<<nickname>>` join the most recently hosted game. If you specify a nickname, it will be used instead of your discord nickname
    - `!join ?<<nickname>> player <<player>>` similar to join, but allows you to join the game that <<player>> is in specifically, instead of always the most recent game
    - `!config <<parameter>> <<value>>` configure game parameters (host only)
    - `!start` start the game (Host only)
    - `!play <<guess>>` guess a number during your turn
    - `!play ?<<nickname>> <<guess>>` use this to guess if you specified a nickname earlier
    - `!restart` restart the game once it's over (Host only)
    ")
    |> Embed.send()
  end

  Cogs.def host() do
    Cogs.member() |> get_discord_name() |> Exec.host_game() |> Embed.send()
  end

  Cogs.set_parser(:join, &List.wrap/1)

  Cogs.def join(args) do
    case join_parse(args) do
      %{nickname: nickname, player: nil} ->
        nickname |> Exec.join_game() |> Embed.send()

      %{nickname: nil, player: player} ->
        Cogs.member() |> get_discord_name() |> Exec.join_game(player) |> Embed.send()

      %{nickname: nickname, player: player} ->
        nickname |> Exec.join_game(player) |> Embed.send()

      _ ->
        Cogs.member() |> get_discord_name() |> Exec.join_game() |> Embed.send()
    end
  end

  Cogs.def config(param, value) do
    Cogs.member() |> get_discord_name() |> Exec.config(param, value) |> Embed.send()
  end

  Cogs.def start() do
    Cogs.member() |> get_discord_name() |> Exec.start_game() |> Embed.send()
  end

  Cogs.def play(player_name, guess) do
    player_name |> Exec.play_game(guess) |> Embed.send()
  end

  Cogs.def play(guess) do
    Cogs.member() |> get_discord_name() |> Exec.play_game(guess) |> Embed.send()
  end

  Cogs.def players() do
    %Embed{}
    |> title("GG.Bot - Player list")
    |> color(0xADD8E6)
    |> description(Guess.players() |> Enum.join("\n"))
    |> Embed.send()
  end

  Cogs.def restart() do
    Cogs.member() |> get_discord_name() |> Exec.restart_game() |> Embed.send()
  end

  # ~
  # Helpers
  # ~
  defp get_discord_name(member) do
    {:ok, %Alchemy.Guild.GuildMember{user: %Alchemy.User{username: player_name}}} = member

    player_name
  end

  defp join_parse(rest) do
    if String.trim(rest) == "" do
      %{nickname: nil, player: nil}
    else
      params = String.split(rest, " ")

      cond do
        length(params) == 1 -> %{nickname: Enum.at(params, 0), player: nil}
        length(params) == 2 -> %{nickname: nil, player: Enum.at(params, 1)}
        length(params) == 3 -> %{nickname: Enum.at(params, 0), player: Enum.at(params, 2)}
        true -> %{nickname: nil, player: nil}
      end
    end
  end
end
