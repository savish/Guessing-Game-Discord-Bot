defmodule Guess do
  @moduledoc """
  Guessing game server module
  """
  alias Guess.{Game, Games, Player, Players}

  @typedoc """
  Error tuple returned when an action is attempted by a player that isn't
  registered on the server
  """
  @type not_found :: {:error, :player_not_found}

  @typedoc """
  Error reasons

  These reasons are ususally returned as the second element in an
  `{:error, reason}` tuple
  """
  @type error ::
          :player_not_host
          | :player_not_found
          | :invalid_action_for_state

  @typedoc """
  Error tuple returned when an action is attempted outside of its correct
  game state.
  """
  @type wrong_state :: {:error, :invalid_action_for_state}

  @typedoc """
  Error tuple returned when an action is attempted by a player that isn't
  the game host
  """
  @type not_host :: {:error, :player_not_host}

  @doc """
  Connect to the server and host a new game

  The player passed to this function will be set as the host of the game. A
  game name can be provided as a second parameter, but if it is not, the name
  of the host is used as the game name.

  Returns an `{:ok, pid()}` tuple on success, where the pid in the tuple is the
  pid of the game process. Failure to host a game for any reason will return an
  error tuple `{:error, String.t()}`
  """
  @spec host(String.t(), String.t()) :: {:ok, pid()} | :error
  def host(host_name, game_name \\ nil)

  def host(host_name, game_name) when is_nil(game_name),
    do: host(host_name, host_name)

  def host(host_name, game_name) do
    with {:ok, _player, _game} <- Players.get_or_create(host_name) do
      Games.create(host_name, game_name)
    else
      _ -> :error
    end
  end

  @doc """
  Connect to the server if necessary and join an existing game

  Expects a `player_name` parameter with the name of the joining player. To
  join a particular game, the name of a player already in that game must be
  provided as the `existing_player_name` parameter. If this isn't provided,
  the player joins the most recently created game.

  Returns `:ok` if successful. The `not_found` error is only
  returned for the `existing_player_name` parameter variant of this function.

  ## States
  - Game is setting up

  See `t:wrong_state/0` and `t:not_found/0` for additional error info.
  """
  @spec join(String.t(), String.t()) :: :ok | {:error, term()}
  def join(player_name, existing_player_name \\ nil)

  def join(player_name, existing_player_name) when is_nil(existing_player_name) do
    with {:ok, _player, _game} <- Players.get_or_create(player_name),
         {:ok, {game, _data}} <- Games.get_latest() do
      Game.add_player(game, player_name)
    end
  end

  def join(player_name, existing_player_name) do
    with {:ok, _player, _game} <- Players.get_or_create(player_name),
         {:ok, game} <- Player.game(existing_player_name) do
      Game.add_player(game, player_name)
    end
  end

  @doc """
  Returns a list of players on the server
  """
  @spec players() :: list(String.t())
  def players() do
    Players.list()
  end

  @doc """
  Configures the game state before starting.

  By default, the game ends when a round ends with one or more players having
  over `300` points. This value is configured by changing the key `max_points`
  to a different value.
  """
  @spec configure(String.t(), keyword()) ::
          :ok | not_host() | not_found() | wrong_state()
  def configure(host_name, opts) do
    if not is_host?(host_name) do
      {:error, :player_not_host}
    else
      # Whitelist options here
      max_points = Keyword.get(opts, :max_points, 300)

      with {:ok, game} <- Player.game(host_name) do
        Game.configure(game, max_points: max_points)
      end
    end
  end

  @doc """
  Starts the game

  Returns `:ok` on success. Expects that the `player_name` parameter is the
  name of the game host. If not, this returns `t:not_host/0`

  ## States
  - Game is setting up

  See `t:wrong_state/0` and `t:not_found/0` for additional error info.
  """
  @spec start(String.t()) ::
          :ok | not_host() | wrong_state() | not_found()
  def start(player_name) do
    with {:ok, game} <- Player.game(player_name) do
      Game.start(game, player_name)
    end
  end

  @doc """
  Processes a player's turn

  The guess must be between 1 and the maximum configured at the start of the
  game. If not, this returns `{:error, :out_of_range}`. Otherwise returns
  `:ok` when successful. Attempting to play outside of the player's turn
  returns `{:error, :wrong_turn}`

  ## States
  - Game is in play

  See `t:wrong_state/0` and `t:not_found/0` for additional error info.
  """
  @spec play(String.t(), non_neg_integer()) ::
          :ok | {:error, :wrong_turn | :out_of_range} | wrong_state() | not_found()
  def play(player_name, guess) do
    with {:ok, game} <- Player.game(player_name) do
      Game.play(game, player_name, guess)
    end
  end

  @doc """
  Restart the game with the same players

  Returns `:ok` if successful. If a player other than the host attempts to
  restart the game, this returns `t:not_host/0`.

  ## States
  - Game has ended

  See `t:wrong_state/0` and `t:not_found/0` for additional error info.
  """
  @spec restart(String.t()) ::
          :ok | not_host() | wrong_state() | not_found()
  def restart(host_name) do
    with {:ok, game} <- Player.game(host_name),
         :host <- Game.role(game, host_name) do
      Game.restart(game)
    else
      :player -> {:error, :player_not_host}
      err -> err
    end
  end

  @doc """
  Clears all players and games from the server

  ## Example

      iex> :ok = Guess.reset()
  """
  @spec reset() :: :ok
  def reset() do
    Players.clear()
    Games.clear()
  end

  # Helpers
  @spec is_host?(String.t()) :: boolean()
  defp is_host?(player_name) do
    with {:ok, game} <- Player.game(player_name),
         {_, data} <- Game.info(game) do
      data.host == player_name
    else
      _ ->
        false
    end
  end
end
