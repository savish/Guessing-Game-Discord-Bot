defmodule Guess.Player do
  @player_registry :"Guess.PlayerRegistry"

  alias Guess.Player
  alias Guess.Game

  @enforce_keys [:name]
  defstruct [:name, :game, is_host: false]

  @typedoc """
  Player data

  ## Fields
  The player's name is a required field. Once a game is hosted/joined, the
  game's `pid` is stored in this struct as well. Additionally, if this player
  is the host, that information is stored in the `is_host` flag.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          game: pid() | nil,
          is_host: boolean
        }

  def info(player_name) do
    with :ok <- player_exists(player_name) do
      GenServer.call(via_player(player_name), :info)
    end
  end

  def host_game(player_name, game) do
    with :ok <- player_exists(player_name) do
      GenServer.call(via_player(player_name), {:host, game})
    end
  end

  def join_game(player_name, host_name) do
    with :ok <- player_exists(player_name) do
      GenServer.call(via_player(player_name), {:join, player_name, host_name})
    end
  end

  def get_game(player_name) do
    with %Player{game: game} <- info(player_name) do
      if game == nil, do: {:error, :game_doesnt_exist}, else: {:ok, game}
    end
  end

  def start_game(player_name) do
    case info(player_name) do
      %Player{is_host: is_host, game: game} when is_host ->
        Game.start(game)

      {:error, _} = err ->
        err

      _ ->
        {:error, :player_isnt_host}
    end
  end

  def play(player_name, guess) do
    with %Player{game: game} <- info(player_name) do
      Game.play(game, player_name, guess)
    end
  end

  def leave_game(player_name) do
    with :ok <- player_exists(player_name) do
      GenServer.call(via_player(player_name), :leave)
    end
  end

  ###########
  # Private #
  ###########
  defp player_exists(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [] -> {:error, :player_doesnt_exist}
      _ -> :ok
    end
  end

  defp via_player(player_name) do
    case player_name do
      {:via, _, _} = via_tuple -> via_tuple
      _ -> {:via, Registry, {@player_registry, player_name}}
    end
  end
end
