defmodule Guess.Player.Server do
  use GenServer

  alias Guess.Game
  alias Guess.Player
  alias Guess.Player.Impl

  @player_registry :"Guess.PlayerRegistry"

  #############
  # Callbacks #
  #############
  @impl true
  def init(opts) do
    {:ok, Impl.new(Keyword.fetch!(opts, :name))}
  end

  @impl true
  def handle_call(:info, _from, data) do
    {:reply, data, data}
  end

  @impl true
  def handle_call({:host, game}, _from, data) do
    new_data = Impl.host_game(data, game)
    {:reply, {:ok, new_data}, new_data}
  end

  @impl true
  def handle_call({:join, player_name, host_name}, _from, data) do
    with {:ok, game} <- Player.get_game(host_name),
         game_info <- Game.join(game, player_name) do
      {:reply, {:ok, game_info}, Impl.join_game(data, game)}
    else
      {:error, :game_doesnt_exist} ->
        {:reply, {:error, "#{host_name} is not currently in a game"}, data}

      {:error, :player_doesnt_exist} ->
        {:reply, {:error, "#{host_name} is not a player on this server"}, data}
    end
  end

  @impl true
  def handle_call(:leave, _from, data) do
    {:reply, :ok, Impl.leave_game(data)}
  end

  ##################
  # Supervisor API #
  ##################
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_player(name))
  end

  ###########
  # Private #
  ###########
  defp via_player(player_name) do
    case player_name do
      {:via, _, _} = via_tuple -> via_tuple
      _ -> {:via, Registry, {@player_registry, player_name}}
    end
  end
end
