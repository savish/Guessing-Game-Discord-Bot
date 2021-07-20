defmodule Guess.Player do
  @moduledoc """
  Player module

  Player related data and functionality is contained in this module. A
  typical game will contain at least 2 players, one of them being the host.
  """
  use Agent
  use TypedStruct

  # NOTE: Using __MODULE__ here doesn't work with ElixirLS for completion
  # alias __MODULE__, as: Player
  alias Guess.Player
  alias Guess.Player.Round

  @player_registry :"Guess.PlayerRegistry"

  typedstruct do
    @typedoc """
    Player data

    ## Fields
    - `name` human readable name
    - `points` total points accrued by the player so far
    - `round_data` data for individual rounds for this player
    """

    field :name, String.t(), enforce: true
    field :points, non_neg_integer, default: 0

    # Note: This list will be stored latest first for easier manipulation.
    # Should be displayed in reverse
    field :round_data, list(Round.t()), default: []
  end

  @doc """
  Creates a new player

  The keyword parameter needs to include the `name` key with the intended name
  of the player.

  See `Agent` for information on return values
  """
  def start_link(opts) do
    player_name = Keyword.fetch!(opts, :name)

    Agent.start_link(
      fn -> %__MODULE__{name: player_name} end,
      name: via_player(player_name)
    )
  end

  @doc """
  Get's the player process data
  """
  @spec info(String.t()) :: t()
  def info(player_name) do
    Agent.get(via_player(player_name), & &1)
  end

  @doc """
  Assigns the given game to the player in the player registry
  """
  @spec register_game(String.t(), pid()) :: :ok
  def register_game(player_name, game) do
    Agent.update(via_player(player_name), fn state ->
      Registry.update_value(@player_registry, player_name, fn _ -> game end)
      state
    end)
  end

  @doc """
  Returns the game this player is in

  Returns an error tuple `{:error, nil}` if the player is not in any game,
  otherwise returns `{:ok, pid}`.

  If any errors are encountered, returns the error tuple as well.
  """
  @spec game(String.t()) :: {:ok, pid()} | {:error, nil}
  def game(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [{_pid, nil}] -> {:error, nil}
      [{_pid, game}] -> {:ok, game}
      _ -> {:error, nil}
    end
  end

  @doc """
  Starts a new player round by appending new round data to the player struct
  """
  @spec start_round(String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def start_round(player_name, round, assigned) do
    Agent.update(via_player(player_name), fn player ->
      %Player{
        player
        | round_data: [Round.new(round, assigned)] ++ player.round_data
      }
    end)
  end

  @doc """
  Records the player's guess to the current round's data
  """
  @spec guess(t(), non_neg_integer()) :: :ok
  def guess(player_name, guess) do
    Agent.update(via_player(player_name), fn player ->
      [current | older] = player.round_data

      %Player{
        player
        | round_data: [Round.guess(current, guess)] ++ older
      }
    end)
  end

  @doc """
  Add bonus points to this player's round
  """
  @spec add_bonus(t(), non_neg_integer(), any()) :: :ok
  def add_bonus(player_name, points, reason) do
    Agent.update(via_player(player_name), fn player ->
      [current | older] = player.round_data

      %Player{
        player
        | round_data: [Round.add_bonus(current, points, reason)] ++ older
      }
    end)
  end

  @doc """
  Calculate the points for this round
  """
  @spec round_points(t()) :: :ok
  def round_points(player_name) do
    Agent.update(via_player(player_name), fn player ->
      [current | older] = player.round_data

      %Player{
        player
        | round_data: [Round.calculate_points(current)] ++ older
      }
    end)
  end

  @doc """
  Calculate the total points the player has accrued so far
  """
  @spec total_points(t()) :: :ok
  def total_points(player_name) do
    Agent.update(via_player(player_name), fn player ->
      %Player{
        player
        | points: player.round_data |> Enum.map(&Map.get(&1, :points)) |> Enum.sum()
      }
    end)
  end

  @doc """
  Reset the player to default
  """
  @spec reset(String.t()) :: :ok
  def reset(player_name) do
    Agent.update(via_player(player_name), fn player ->
      %Player{player | points: 0, round_data: []}
    end)
  end

  # Helpers #
  defp via_player(player_name, game \\ nil) do
    case player_name do
      {:via, _, _} = via_tuple -> via_tuple
      _ -> {:via, Registry, {@player_registry, player_name, game}}
    end
  end
end
