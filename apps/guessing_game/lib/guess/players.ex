defmodule Guess.Players do
  @moduledoc false
  use Supervisor

  alias Guess.Player

  @player_registry :"Guess.PlayerRegistry"

  # Supervisor API #
  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Client API #
  @spec create(String.t()) :: {:ok, pid()} | {:error, :player_name_taken | String.t()}
  def create(player_name) when not is_nil(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [{_, _}] ->
        {:error, :player_name_taken}

      _ ->
        spec = {Player, [name: player_name]}

        case DynamicSupervisor.start_child(Guess.PlayerSupervisor, spec) do
          {:ok, pid} -> {:ok, pid, nil}
          {:error, {:already_started, _pid}} -> {:error, :player_name_taken}
          {:error, reason} -> {:error, reason}
          _ -> {:error, "Unable to join the server"}
        end
    end
  end

  def create(_player_name) do
    {:error, "Invalid player name"}
  end

  @spec get(String.t()) :: {:ok, pid(), pid() | nil} | {:error, atom()}
  def get(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [{pid, game}] -> {:ok, pid, game}
      _ -> {:error, :player_not_found}
    end
  end

  @doc """
  Gets or creates a new player

  Returns an `{:ok, player_pid, game_pid}` tuple on success. If the player is
  not in a game, the `game_pid` will be `nil`
  """
  @spec get_or_create(String.t()) :: {:ok, pid(), pid() | nil} | {:error, atom()}
  def get_or_create(player_name) do
    case get(player_name) do
      {:ok, pid, game} ->
        {:ok, pid, game}

      _ ->
        create(player_name)
    end
  end

  @spec delete(String.t()) :: :ok
  def delete(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [] ->
        :ok

      [{pid, _}] ->
        Registry.unregister(@player_registry, player_name)
        DynamicSupervisor.terminate_child(Guess.PlayerSupervisor, pid)
        :ok
    end
  end

  @spec list() :: list(String.t())
  def list() do
    stream =
      DynamicSupervisor.which_children(Guess.PlayerSupervisor)
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(&Registry.keys(@player_registry, &1))

    Enum.to_list(stream) |> List.flatten()
  end

  @spec exists?(String.t()) :: bool
  def exists?(player_name) do
    case Registry.lookup(@player_registry, player_name) do
      [] -> false
      _ -> true
    end
  end

  @spec clear() :: :ok
  def clear() do
    if length(list()) > 0 do
      DynamicSupervisor.which_children(Guess.PlayerSupervisor)
      |> Enum.map(&elem(&1, 1))
      |> Enum.each(&DynamicSupervisor.terminate_child(Guess.GameSupervisor, &1))
    end

    :ok
  end

  # Callbacks #
  @impl true
  def init(:ok) do
    children = [
      {Registry, [keys: :unique, name: @player_registry]},
      {DynamicSupervisor, name: Guess.PlayerSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_all]
    Supervisor.init(children, opts)
  end
end
