defmodule Guess.Player.Round do
  @moduledoc """
  Functionality related to player data during individual game rounds

  Each player gets a turn per round. The round data includes the assigned
  numbers as well as the guessed ones, and the bonus points the player may
  have received.

  The example below shows the typical lifecycle of a player's round data.

  ## Example

  Player round data structs are assigned to each player when the game round
  starts. Once the player makes a guess in their turn, their round data for
  that turn is updated. If there are any bonuses these are added after the
  guess. Finally the points for the round are computed.

      iex> alias Guess.Player.{Round, Bonus}
      iex> Round.new(1, 47)
      ...>   |> Round.guess(74)
      ...>   |> Round.add_bonus(25, :reverse_match)
      ...>   |> Round.calculate_points()
      %Round{
        assigned: 47,
        bonuses: [%Bonus{reason: :reverse_match, value: 25}],
        guess: 74,
        points: 98,
        round: 1
      }
  """

  alias Guess.Player.{Bonus, Round}
  use TypedStruct

  typedstruct do
    @typedoc """
    Player data for a single round

    ## Parameters
    - `round` round identifier (usually just the round number in the game)
    - `assigned` number assigned to this player for this round by the game
    - `guess` number that the player guessed for the round
    - `points` points for this round, based on the player's guess
    - `bonuses` all bonuses that apply to this round for the player
    """

    field :round, non_neg_integer, enforce: true
    field :assigned, non_neg_integer, enforce: true
    field :guess, non_neg_integer
    field :points, non_neg_integer
    field :bonuses, list(Bonus.t()), default: []
  end

  @doc """
  Creates and returns new round data

  ## Parameters
  - `round`: round identifier
  - `assigned`: the number assigned to this round (for a specific player)

  See `Guess.Player.Round` for examples
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(round, assigned) do
    %Round{round: round, assigned: assigned}
  end

  @doc """
  Updates the round data with the player's guess

  ## Parameters
  - `data`: round data
  - `guess`: the player's guess for the round

  See `Guess.Player.Round` for examples
  """
  @spec guess(t(), non_neg_integer()) :: t()
  def guess(data, guess) do
    %Round{data | guess: guess}
  end

  @doc """
  Adds any bonuses the player qualifies for this round

  ## Parameters
  - `data`: round data
  - `value`: value of the bonus in points
  - `reason`: reason for the bonus

  See `Guess.Player.Round` for examples
  """
  @spec add_bonus(t(), non_neg_integer(), any()) :: t()
  def add_bonus(data, value, reason) do
    %Round{
      data
      | bonuses: data.bonuses ++ [Bonus.new(value, reason)]
    }
  end

  @doc """
  Calculates the total point value for the round

  ## Parameters
  - `data`: round data

  See `Guess.Player.Round` for examples
  """
  @spec calculate_points(t()) :: t()
  def calculate_points(data) do
    difference = 100 - abs(data.guess - data.assigned)

    bonuses =
      data.bonuses
      |> Enum.map(&Map.get(&1, :value))
      |> Enum.sum()

    %Round{data | points: difference + bonuses}
  end
end
