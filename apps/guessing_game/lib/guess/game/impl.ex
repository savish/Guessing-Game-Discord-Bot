defmodule Guess.Game.Impl do
  alias Guess.Game

  @doc """
  Creates a new game

  Games are identified by the host player. Once a game has been hosted, it
  enters the setting up state, where other players can join in.
  """
  @spec new(String.t(), keyword) :: Game.state_and_data()
  def new(host, opts \\ []) do
    {:setting_up,
     %Game{
       host: host,
       players: [host],
       max_points: Keyword.get(opts, :max_points, 300),
       guess_from: Keyword.get(opts, :guess_from, 1),
       guess_to: Keyword.get(opts, :guess_to, 100)
     }}
  end

  @doc """
  Adds the given player to the game
  """
  @spec join(Game.t(), String.t()) :: Game.t()
  def join(data, player_name) do
    %Game{data | players: data.players ++ [player_name]}
  end

  @doc """
  Start the game

  A custom turn order can be provided. Otherwise the turns will be according to
  game join order (starting with the host)
  """
  @spec start(Game.t(), [integer()]) :: Game.t()
  def start(data, turn_order) do
    %Game{
      data
      | turn_order: turn_order,
        round: 1,
        chosen_numbers:
          data.players
          |> Enum.reduce(data.chosen_numbers, &Map.put_new(&2, &1, :rand.uniform(100))),
        points: data.players |> Enum.reduce(data.points, &Map.put_new(&2, &1, 0))
    }
  end

  @doc """
  Start the game, using the player join order as the turn order
  """
  @spec start(Game.t()) :: Game.t()
  def start(data) do
    start(data, 0..(length(data.players) - 1) |> Enum.to_list())
  end

  @spec end_turn(Game.t(), String.t(), integer()) :: Game.t()
  def end_turn(data, player_name, guess) do
    {_, points} =
      data.points
      |> Map.get_and_update(
        player_name,
        &{&1, &1 + calculate_points(Map.get(data.chosen_numbers, player_name), guess)}
      )

    # round_turn = rem(data.absolute_turn, length(data.players)) -- sever
    %Game{
      data
      | points: points,
        absolute_turn: data.absolute_turn + 1
    }
  end

  @spec end_round(Game.t()) :: Game.t()
  def end_round(data) do
    %Game{
      data
      | round: data.round + 1,
        chosen_numbers:
          data.players
          |> Enum.reduce(data.chosen_numbers, &Map.put_new(&2, &1, :rand.uniform(100)))
    }
  end

  @spec is_game_over?(Game.t()) :: boolean()
  def is_game_over?(data) do
    winners = Enum.filter(data.points, fn {_k, v} -> v >= data.max_points end)
    length(winners) > 0
  end

  @doc """
  Returns a summary string of the current game state
  """
  @spec summary(Game.state_and_data()) :: String.t()
  def summary({state, data}) do
    "#{data.host}'s game: #{state_to_string(state)}"
  end

  @spec players(Game.t()) :: [String.t()]
  def players(data) do
    data.players
  end

  ###########
  # Private #
  ###########

  @spec state_to_string(Game.state()) :: String.t()
  defp state_to_string(state) do
    case state do
      :setting_up ->
        "Setting up"

      :ended ->
        "Ended"

      {:round, round, :turn, turn} ->
        if turn == :end do
          "End of round #{round}"
        else
          "Round #{round}, #{turn}'s turn"
        end
    end
  end

  @spec calculate_points(integer(), integer()) :: integer()
  defp calculate_points(chosen, guess) do
    100 - abs(guess - chosen)
  end
end
