defmodule Guess.Games do
  @moduledoc false
  use Supervisor

  alias Guess.{Player, Game}

  # Supervisor API #
  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Client API #
  @spec create(String.t(), String.t()) :: {:ok, pid()} | {:error, term()}
  def create(host_name, game_name) do
    spec = {Game, [host: host_name, name: game_name]}

    with {:ok, pid} <- DynamicSupervisor.start_child(Guess.GameSupervisor, spec) do
      Player.register_game(host_name, pid)
      {:ok, pid}
    end
  end

  @spec list() :: list(String.t())
  def list() do
    stream =
      DynamicSupervisor.which_children(Guess.GameSupervisor)
      |> Stream.map(&elem(&1, 1))
      |> Stream.map(&{&1, Game.info(&1)})

    Enum.to_list(stream) |> List.flatten()
  end

  @doc """
  Returns the latest game created

  If there are no games created on the server, returns an error tuple
  `{:error, nil}`
  """
  @spec get_latest() :: {:ok, pid} | {:error, nil}
  def get_latest() do
    games = list()

    if length(games) > 0 do
      {:ok, games |> Enum.take(-1) |> hd()}
    else
      {:error, nil}
    end
  end

  @spec clear() :: :ok
  def clear() do
    if length(list()) > 0 do
      DynamicSupervisor.which_children(Guess.GameSupervisor)
      |> Enum.map(&elem(&1, 1))
      |> Enum.each(&DynamicSupervisor.terminate_child(Guess.GameSupervisor, &1))
    end

    :ok
  end

  # Callbacks #
  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: Guess.GameSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_all]
    Supervisor.init(children, opts)
  end
end
