defmodule Bot.Application do
  @moduledoc false
  use Application
  alias Alchemy.Client
  alias Guess.Server
  alias Guess.Player

  defmodule Commands do
    use Alchemy.Cogs

    Cogs.def help() do
      help = """
      ```
      Welcome to the Guessing Game!
      ==

      # Controls

      - !connect (?name) connect to the game server.
      - !dc (?name) disconnect from the game server.
      ```
      """

      Cogs.say(help)
    end

    Cogs.def connect(player_name) do
      Cogs.say(player_name |> connnect_to_server() |> response_fmt())
    end

    Cogs.def connect() do
      Cogs.say(Cogs.member() |> get_discord_name() |> connnect_to_server() |> response_fmt())
    end

    Cogs.def dc(player_name) do
      Cogs.say(player_name |> disconnect_from_server() |> response_fmt())
    end

    Cogs.def dc() do
      Cogs.say(Cogs.member() |> get_discord_name() |> disconnect_from_server() |> response_fmt())
    end

    Cogs.def host(player_name) do
      Cogs.say(player_name |> host_game() |> response_fmt())
    end

    Cogs.def host() do
      Cogs.say(Cogs.member() |> get_discord_name() |> host_game() |> response_fmt())
    end

    Cogs.def join(player_name, host_name) do
      Cogs.say(player_name |> join_game(host_name) |> response_fmt())
    end

    Cogs.def join(host_name) do
      Cogs.say(Cogs.member() |> get_discord_name() |> join_game(host_name) |> response_fmt())
    end

    Cogs.def start(player_name) do
      Cogs.say(player_name |> start_game() |> response_fmt())
    end

    Cogs.def start() do
      Cogs.say(Cogs.member() |> get_discord_name() |> start_game() |> response_fmt())
    end

    Cogs.def play(player_name, guess) do
      Cogs.say(player_name |> play_game(guess) |> response_fmt())
    end

    Cogs.def play(guess) do
      Cogs.say(Cogs.member() |> get_discord_name() |> play_game(guess) |> response_fmt())
    end

    Cogs.def players() do
      players = Server.list_players()

      response =
        players
        |> Enum.with_index(1)
        |> Enum.map(fn {index, player} -> "#{player}. #{index}" end)
        |> Enum.join("\n")

      Cogs.say(response)
    end

    Cogs.def games() do
      games = Server.list_games()

      response =
        games
        |> Enum.with_index(1)
        |> Enum.map(fn {index, game} -> "#{game}. #{index}" end)
        |> Enum.join("\n")

      Cogs.say(response)
    end

    ## Private

    @spec response_fmt(String.t()) :: String.t()
    defp response_fmt(resp) do
      # Wraps the response in a code block
      "```#{resp}```"
    end

    defp get_discord_name(member) do
      {:ok, %Alchemy.Guild.GuildMember{user: %Alchemy.User{username: player_name}}} = member

      player_name
    end

    @spec connnect_to_server(String.t()) :: String.t()
    defp connnect_to_server(player_name) do
      case Server.connect(player_name) do
        {:error, :player_name_taken} ->
          "Player name taken! Please choose another using '!connect <<name>>'"

        {:error, reason} ->
          to_string(reason)

        _ ->
          "Successfully connected to the Guessing Game server, #{player_name}!"
      end
    end

    @spec disconnect_from_server(String.t()) :: String.t()
    defp disconnect_from_server(player_name) do
      case Server.dc(player_name) do
        {:error, :player_doesnt_exist} ->
          "#{player_name} is not connected to this server"

        :ok ->
          "#{player_name} has left the server."
      end
    end

    @spec host_game(String.t()) :: String.t()
    defp host_game(player_name) do
      case Server.host(player_name) do
        {:ok, summary} -> summary
        {:error, :game_in_progress} -> "This game is already in progress"
        {:error, other} -> other
      end
    end

    @spec join_game(String.t(), String.t()) :: String.t()
    defp join_game(player_name, host_name) do
      case Server.join(player_name, host_name) do
        :ok -> "Joined #{host_name}'s game"
        _ -> "Unable to join #{host_name}'s game"
      end
    end

    @spec start_game(String.t()) :: String.t()
    defp start_game(player_name) do
      case Player.start_game(player_name) do
        {:ok, {:round, round, :turn, turn}} ->
          "Game started!\n==\nRound #{round}, #{turn}'s turn\nEnter your guess: "

        {:error, :player_isnt_host} ->
          "Only the host can start a game"

        {:error} ->
          "Unable to start the game"
      end
    end

    defp play_game(player_name, guess) do
      case Player.play(player_name, String.to_integer(guess)) do
        {:end_turn, {:round, round, :turn, turn}} ->
          "Round #{round}, #{turn}'s turn\nEnter your guess: "

        {:end_round, {{:round, round, :turn, turn}, points}} ->
          point_string = Enum.reduce(points, "", fn {k, v}, acc -> "#{acc}#{k} => #{v} " end)

          "Round finished.\nCurrent points: #{point_string}\n\nNew round\n==\nRound #{round}, #{
            turn
          }'s turn\nEnter your guess: "

        {:end_round, {:ended, points}} ->
          point_string = Enum.reduce(points, "", fn {k, v}, acc -> "#{acc}#{k} => #{v} " end)
          "Game over!!\nFinal score: #{point_string}"
      end
    end
  end

  def start(_type, _args) do
    token = Application.fetch_env!(:discord_bot, :token)
    run = Client.start(token)
    use Commands
    run
  end
end
