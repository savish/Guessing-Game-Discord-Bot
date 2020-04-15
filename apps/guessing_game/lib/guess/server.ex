defmodule Guess.Server do
  @moduledoc """
  Server management module
  ==
  """

  @player_registry :"Guess.PlayerRegistry"
  alias Guess.PlayerSupervisor, as: PSup
  alias Guess.GameSupervisor, as: GSup
  alias Guess.Player
  alias Guess.Game

  defstruct players: [], games: []

  @type t :: %__MODULE__{
          players: list(String.t()),
          games: list(String.t())
        }

  @doc """
  Server info

  ## Returns
  Returns a two-key map. The `players` key holds a list of players on the
  server, whereas the `games` key lists all games on the server.

  ## Examples

        iex> %Guess.Server{players: players, games: games} = Guess.Server.info()
  """
  @spec info :: Guess.Server.t()
  def info() do
    %__MODULE__{
      players: list_players(),
      games: list_games()
    }
  end

  @doc """
  Connect to the server

  Only players connected to the server can host/join game instances.

  ## Examples

      iex> :ok = Guess.Server.connect("Player 1")
  """
  def connect(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [{_, _}] ->
        {:error, :player_name_taken}

      _ ->
        spec = {Player.Server, [name: player_name]}

        case DynamicSupervisor.start_child(PSup, spec) do
          {:ok, _pid} -> {:ok, info()}
          {:error, {:already_started, _pid}} -> {:error, :player_name_taken}
          {:error, reason} -> {:error, reason}
          _ -> {:error, "Unable to join the server"}
        end
    end
  end

  @doc """
  Disconnect the player from the server

  ## Examples

      iex> :ok = Server.connect("Disconn")
      iex> :ok = Server.dc("Disconn")
  """
  def dc(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [] ->
        {:error, :player_doesnt_exist}

      [{pid, _}] ->
        Registry.unregister(@player_registry, player_name)
        DynamicSupervisor.terminate_child(PSup, pid)
        :ok
    end
  end

  @doc """
  Host a new game instance on the server

  The host player has to be connected to the server.

  ## Examples

      iex> p1 = "Player 1"
      iex> :ok = Server.connect(p1)
      iex> p1 |> Server.host()
  """
  @spec host(String.t()) :: {:ok, any} | {:error, any}
  def host(player_name) do
    spec = {Game.Server, [host: player_name]}

    with {:ok, pid} <- DynamicSupervisor.start_child(GSup, spec),
         {:ok, _player} <- Player.host_game(player_name, pid) do
      {:ok, Game.summary(pid)}
    else
      {:error, {:already_started, _pid}} -> {:error, :game_in_progress}
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Unable to host the game"}
    end
  end

  @doc """
  Join an existing game

  The game must be in a state that allows players to join. Additionally any
  joining players have to be connected to the server already.

  ## Examples

      iex> {:ok, _server_info} = Server.connect("host")
      iex> {:ok, _server_info} = Server.connect("join")
      iex> {:ok, _game_info} = "host" |> Server.host
      iex> {:ok, _game_info} = "host" |> Server.join
  """
  def join(player_name, host_name) do
    Player.join_game(player_name, host_name)
  end

  def end_game(player_name) do
    case Player.get_game(player_name) do
      {:ok, game} ->
        Game.players(game) |> Enum.each(fn player -> Player.leave_game(player) end)
        DynamicSupervisor.terminate_child(GSup, game)

      error ->
        error
    end
  end

  @spec list_players :: list(String.t())
  def list_players() do
    stream =
      DynamicSupervisor.which_children(PSup)
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(&Registry.keys(@player_registry, &1))

    Enum.to_list(stream) |> List.flatten()
  end

  @spec list_games :: list(String.t())
  def list_games() do
    stream =
      DynamicSupervisor.which_children(GSup)
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(&Game.summary(&1))

    Enum.to_list(stream) |> List.flatten()
  end
end
