defmodule Guess.Game do
  @moduledoc """
  Game API

  Using this API requires a game `pid` for most of the functionality
  """
  alias GenStateMachine, as: GSM

  @enforce_keys [:host, :players]
  defstruct [
    :host,
    :players,
    chosen_numbers: %{},
    max_points: 300,
    guess_from: 1,
    guess_to: 100,
    round: 0,
    turn_order: [],
    absolute_turn: 0,
    points: %{}
  ]

  @typedoc """
  Game state data
  """
  @type t :: %__MODULE__{
          host: String.t(),
          players: [String.t()],
          round: integer(),
          max_points: integer(),
          guess_from: integer(),
          guess_to: integer(),
          turn_order: [integer()],
          absolute_turn: integer(),
          chosen_numbers: %{optional(String.t()) => integer()},
          points: %{optional(String.t()) => integer()}
        }

  @typedoc """
  Game states

  A hosted game starts in the `setting_up` state. In this state, players can
  join the game. Once the host starts the game, it proceeds into the rounds
  until the game end condition is met. At that point, the game transitions to
  the ended state.

  In the rounds state, numeric turn values indicate player turns, whereas the
  `:end` turn value indicates the end of a round - allowing for a score display
  """
  @type state ::
          :setting_up
          | {:round, integer(), :turn, :end | String.t()}
          | :ended

  @typedoc """
  State and data tuple
  """
  @type state_and_data :: {state(), t()}

  def summary(game) do
    GSM.call(game, :summary)
  end

  def players(game) do
    GSM.call(game, :players)
  end

  def join(game, player_name) do
    GSM.call(game, {:join, player_name})
  end

  def start(game) do
    GSM.call(game, :start)
  end

  def play(game, player_name, guess) do
    GSM.call(game, {:play, player_name, guess})
  end
end
