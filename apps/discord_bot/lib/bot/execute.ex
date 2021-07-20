defmodule Bot.Execute do
  @moduledoc false

  import Alchemy.Embed
  alias Alchemy.Embed
  alias Guess.{Player, Game}

  @spec host_game(String.t()) :: Embed.t()
  def host_game(host_name) do
    with {:ok, game} <- Guess.host(host_name),
         {_, game_data} <- Game.info(game) do
      %Embed{}
      |> title("GG.Bot - New Game Hosted")
      |> color(0xADD8E6)
      |> description("A new game has been hosted by #{game_data.host}.\n
          Use `!join` to join the game.")
    end
  end

  @spec join_game(String.t(), String.t() | nil) :: Embed.t()
  def join_game(player_name, host_name \\ nil) do
    with :ok <- Guess.join(player_name, host_name),
         {:ok, game} = Player.game(player_name),
         {_, game_data} = Game.info(game) do
      %Embed{}
      |> title("GG.Bot - Joined game")
      |> color(0xADD8E6)
      |> description("#{player_name} has joined #{game_data.host}'s game.\n
          #{game_data.host} can use `!start` to start the game.")
    else
      {:error, reason} ->
        send_error(reason)

      _ ->
        send_error("Unable to host the game")
    end
  end

  def config(host_name, param, value) when param in ["max_points"] do
    case Guess.configure(host_name, max_points: String.to_integer(value)) do
      :ok ->
        %Embed{}
        |> title("Configutation updated")
        |> color(0xADD8E6)
        |> description("Parameter __#{param}__ is now set to `#{value}`")

      {:error, reason} ->
        send_error(reason)

      _ ->
        send_error("Unable to configure the game")
    end
  end

  def config(_host_name, param, _value) do
    send_error("__#{param}__ is not a valid configuration parameter")
  end

  @spec start_game(String.t()) :: Embed.t()
  def start_game(player_name) do
    with {:next_turn, {:round, round, :turn, turn}} <- Guess.start(player_name) do
      %Embed{}
      |> title("Game started!")
      |> color(0xADD8E6)
      |> description("Round #{round + 1}, __#{turn}'s__ turn.\n
          Use `!play <<number>>` to guess your assigned number
        ")
    else
      {:error, reason} ->
        send_error(reason)

      _ ->
        send_error("Unable to start game")
    end
  end

  def play_game(player_name, guess) do
    case Guess.play(player_name, String.to_integer(guess)) do
      {:next_turn, {:round, round, :turn, turn}} ->
        %Embed{}
        # |> title("GG.Bot - Next Turn")
        |> color(0xADD8E6)
        |> description("Round #{round + 1}, __#{turn}'s__ turn.\n
          Use `!play <<number>>` to guess your assigned number
        ")

      {:next_round, {:round, round, :turn, turn}} ->
        with {:ok, game} <- Player.game(player_name),
             {_, game_data} <- Game.info(game),
             {round_points, total_points, _} <- get_points(game_data.players) do
          %Embed{}
          |> title("New Round!")
          |> color(0xADD8E6)
          |> field("Previous round", round_points)
          |> field("Total so far", total_points)
          |> description("Round #{round}, __#{turn}'s__ turn\n
          Use `!play <<number>>` to guess your assigned number
        ")
        end

      :ended ->
        with {:ok, game} <- Player.game(player_name),
             {_, game_data} <- Game.info(game),
             {round_points, total_points, point_values} <- get_points(game_data.players, 0) do
          {winner, _} = Enum.max_by(point_values, fn {_, tp} -> tp end)

          %Embed{}
          |> title("Game Over!")
          |> color(0xADD8E6)
          |> field("Previous round", round_points)
          |> field("Final score", total_points)
          |> description("Everyone wins! Just kidding...\n\n__#{winner}__ wins!!")
        end

      {:error, reason} ->
        send_error(reason)
    end
  end

  def restart_game(player_name) do
    case Guess.restart(player_name) do
      {:next_turn, {:round, round, :turn, turn}} ->
        %Embed{}
        |> title("Game Restarted")
        |> color(0xADD8E6)
        |> description("Round #{round + 1}, __#{turn}'s__ turn.\n
          Use `!play <<number>>` to guess your assigned number
        ")

      {:error, reason} ->
        send_error(reason)

      _ ->
        send_error("Unable to restart game")
    end
  end

  def display_round_data(player_name, round_data) do
    "#{player_name}, round #{round_data.round + 1}"
  end

  def send_error(reason) do
    %Embed{}
    |> title("GG.Bot Error!")
    |> color(0xFF1A1A)
    |> description(
      case reason do
        :player_not_host ->
          "This action can only be performed by the game host."

        :invalid_action_for_state ->
          "This action cannot be performed during this stage of the game"

        :player_not_found ->
          "This player is not on the game server"

        :player_in_game ->
          "This player is already in the game"

        _ ->
          "#{reason}"
      end
    )
  end

  # ~
  # Helpers
  # ~
  defp get_points(players, offset \\ 1) do
    point_values =
      players
      |> Enum.map(fn player ->
        player_data = Player.info(player)
        {player, player_data.points}
      end)

    round_points =
      players
      |> Enum.map(fn player ->
        get_round_points(player, Enum.at(Player.info(player).round_data, offset))
      end)
      |> Enum.join("\n")

    total_points =
      players
      |> Enum.map(&get_total_points/1)
      |> Enum.join("\n")

    {round_points, total_points, point_values}
  end

  @spec get_total_points(String.t()) :: String.t()
  defp get_total_points(player) do
    "__#{player}__ => **#{Player.info(player).points}**"
  end

  @spec get_round_points(String.t(), Player.Round.t()) :: String.t()
  defp get_round_points(player, round_data) do
    ans = "__#{player}__ => **#{round_data.points}**"
    ans = ans <> " (*assigned* `#{round_data.assigned}`, _guessed_ `#{round_data.guess}`)"
    round_bonuses = get_round_bonuses(round_data.bonuses)

    ans <>
      case round_bonuses do
        "" -> ""
        _ -> "\n#{round_bonuses}"
      end
  end

  defp get_round_bonuses(bonuses) do
    Enum.reduce(bonuses, "", fn %Player.Bonus{value: value, reason: reason}, acc ->
      acc <>
        case reason do
          :exact_match ->
            "+ You Guessed Correctly! `#{value}` points!\n"

          :reverse_match ->
            "+ Oooh, Inverse Match - Nice! `#{value}` points!\n"

          {:other_match, player_name} ->
            "+ Guessed __#{player_name}'s__ number! `#{value}` points!\n"

          _ ->
            ""
        end
    end)
  end
end
