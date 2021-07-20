defmodule Guess.Game do
  @moduledoc """
  Game module

  All game state is managed in this module. The game uses the state machine
  behaviour, limiting certain actions to specific game states.

  The game proceeds through the states described by `t:state/0`
  """

  use GenStateMachine

  use TypedStruct
  alias GenStateMachine, as: GSM
  alias Guess.Player
  alias Guess.Game

  typedstruct module: Configuration do
    @moduledoc "Game configuration module"
    @typedoc """
    Game configuration options

    ## Fields
    - `max_points` Max points threshold. Once a player passes this value in a
      round, it becomes the last round. Defaults to 300
    - `max_guess` Maximum allowed guess value. Defaults to 100.
    """

    field :max_points, non_neg_integer(), default: 300
    field :max_guess, non_neg_integer(), default: 100
  end

  typedstruct do
    @typedoc """
    Game state data

    ## Fields
    - `host` Game host
    - `name` Game name. Usually defaults to `<<hosts>>'s game`
    - `players` List of the names of players in the game
    - `round` Current round
    - `turn` Current turn
    - `config` Game configuration data
    """

    # The player name is enough for the host field
    field :host, String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :players, list(Player.t()), default: []
    field :round, non_neg_integer(), default: 0
    field :turn, non_neg_integer(), default: 0
    field :config, Game.Configuration.t(), enforce: true
  end

  @typedoc """
  Game states

  A hosted game starts in the `:setting_up` state. In this state, players can
  join the game, and the host can change game configuration. Once done, the
  host starts the game, moving into the `:in_play` state. Player turns are
  assigned according to join order.

  Once the game is completed it transitions to the `:ended` state. In this
  state the host can choose to reconfigure and restart the game. Additional
  players can join and this is the recommended state for existing players to
  leave if necessary. Finally the host can choose to end the game, which
  removes all players from it and then removes it from the server. It does not
  disconnect the players from the server
  """
  @type state :: :setting_up | :in_play | :ended

  # Guards #
  defguardp is_host(data, player_name) when data.host == player_name

  defguardp is_valid_guess(data, guess) when data.config.max_guess >= guess and guess > 0

  # Supervisor API #

  @doc """
  Creates a new game

  The `host` keyword parameter is expected, and is used to set the name of
  the game host. If the `name` parameter is provided, it is used as the game
  name. Otherwise the host name is used.

  See `GenStateMachine.start_link/2` for information on return values
  """
  def start_link(opts) do
    host_name = Keyword.fetch!(opts, :host)

    game_name =
      case Keyword.fetch(opts, :name) do
        {:ok, name} -> name
        _ -> host_name
      end

    GSM.start_link(
      __MODULE__,
      {:setting_up,
       %Game{
         host: host_name,
         name: game_name,
         players: [host_name],
         config: %Game.Configuration{}
       }}
    )
  end

  # Client API #
  @doc """
  Get game information

  Given the game `pid` this returns all the game data, as well as the current
  state of the game in a tuple `{state, data}`
  """
  @spec info(pid()) :: {state(), t()}
  def info(game) do
    GSM.call(game, :info)
  end

  @doc """
  Gets the player's role in the game

  This is either `:host` or `:player`. If the given player isn't in this game,
  this returns `{:error, :player_not_found}`
  """
  @spec role(pid(), String.t()) :: :host | :player | {:error, :player_not_found}
  def role(game, player_name) do
    GSM.call(game, {:role, player_name})
  end

  @doc """
  Configure the game parameters

  Receives a keyword list containing the name of the setting to change and the
  new value. Returns `:ok`.

  ## States
  This action is only valid in the `:setting_up` and `:ended` states. Calling
  it during any other state returns `{:error, :invalid_action_for_state}`
  """
  @spec configure(pid(), keyword()) :: :ok
  def configure(game, opts) do
    GSM.call(game, {:configure, opts})
  end

  @doc """
  Add a new player to the specified game

  Returns `:ok` on success. If the given player is already in the game, this
  returns `{:error, :player_in_game}`

  ## States
  This action is only valid in the `:setting_up` and `:ended` states. Calling
  it during any other state returns `{:error, :invalid_action_for_state}`
  """
  @spec add_player(pid(), String.t()) :: :ok | {:error, :player_in_game}
  def add_player(game, player_name) do
    :ok = Player.register_game(player_name, game)
    GSM.call(game, {:add_player, player_name})
  end

  @doc """
  Starts a new game session

  Returns `:ok`. This can only be called by the game host. If a player other
  than the host calls this, it returns `{:error, :player_not_host}`

  ## States
  This action is only valid in the `:setting_up` and `:ended` states. Calling
  it during any other state returns `{:error, :invalid_action_for_state}`
  """
  @spec start(pid, String.t()) :: :ok | {:error, :player_not_host | :invalid_action_for_state}
  def start(game, host_name) do
    GSM.call(game, {:start, host_name})
  end

  @doc """
  Processes a player's turn

  ## Returns
  - `{:next_turn, {:round, round, :turn, player_name}}` - this is returned if
  the game is continuing in the same round
  - `{:next_round, {:round, round, :turn, player_name}}` - this is returned if
  the game is continuing in the next round
  - `:ended` - this is returned if the game has concluded

  Returns `{:error, :wrong_turn}` if it isn't the specified player's turn. If
  the guess provided is outside of the allowed guess range specified in the
  game configuration, returns `{:error, :out_of_range}`.

  ## States
  This action is only valid in the `:in_play` state. Calling it during any
  other state returns `{:error, :invalid_action_for_state}`
  """
  @spec play(pid(), String.t(), non_neg_integer()) ::
          :ok | {:error, :out_of_range | :wrong_turn | :invalid_action_for_state}
  def play(game, player_name, guess) do
    GSM.call(game, {:play, player_name, guess})
  end

  @doc """
  Restarts a game with the same players and configuration

  Game goes straight into the `in_play` state. Returns `:ok` if successful,
  and an error tuple if called from the wrong state

  ## States
  - `:ended`
  """
  @spec restart(pid()) :: :ok | {:error, :invalid_action_for_state}
  def restart(game) do
    GSM.call(game, :restart)
  end

  # Handlers #

  # => :info
  @impl true
  def handle_event({:call, from}, :info, state, data) do
    {:keep_state_and_data, [{:reply, from, {state, data}}]}
  end

  # => :role
  @impl true
  def handle_event({:call, from}, {:role, player_name}, _state, data) do
    reply =
      cond do
        data.host == player_name -> :host
        player_name in data.players -> :player
        true -> {:error, :player_not_found}
      end

    {:keep_state_and_data, [{:reply, from, reply}]}
  end

  # => :configure
  @impl true
  def handle_event({:call, from}, {:configure, opts}, state, data)
      when state in [:setting_up, :ended] do
    {:keep_state, do_configure(data, opts), [{:reply, from, :ok}]}
  end

  @impl true
  def handle_event({:call, from}, {:configure, _opts}, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  # => :add_player
  @impl true
  def handle_event({:call, from}, {:add_player, player_name}, :setting_up, data) do
    case do_add_player(data, player_name) do
      {:ok, new_data} -> {:keep_state, new_data, [{:reply, from, :ok}]}
      {:error, _} = reply -> {:keep_state_and_data, [{:reply, from, reply}]}
    end
  end

  @impl true
  def handle_event({:call, from}, {:add_player, _}, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  # => :start
  @impl true
  def handle_event({:call, from}, {:start, _host_name}, state, _data)
      when state not in [:setting_up, :ended] do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  @impl true
  def handle_event({:call, from}, {:start, host_name}, _state, data)
      when not is_host(data, host_name) do
    {:keep_state_and_data, [{:reply, from, {:error, :player_not_host}}]}
  end

  @impl true
  def handle_event({:call, from}, {:start, _host_name}, _state, data) do
    {:next_state, :in_play, do_start_round(data),
     [{:reply, from, {:next_turn, {:round, 0, :turn, Enum.at(data.players, 0)}}}]}
  end

  # => :play
  @impl true
  def handle_event({:call, from}, {:play, _player_name, guess}, {:in_play, _turn}, data)
      when not is_valid_guess(data, guess) do
    {:keep_state_and_data, [{:reply, from, {:error, :out_of_range}}]}
  end

  @impl true
  def handle_event({:call, from}, {:play, player_name, guess}, :in_play, data) do
    if is_player_turn?(data, player_name) do
      case do_play(data, player_name, guess) do
        :next_turn ->
          next_turn = data.turn + 1

          {:keep_state, %__MODULE__{data | turn: next_turn},
           [
             {:reply, from,
              {:next_turn, {:round, data.round, :turn, Enum.at(data.players, next_turn)}}}
           ]}

        :end_round ->
          new_round = data.round + 1
          new_data = %__MODULE__{data | round: new_round, turn: 0}
          do_start_round(new_data)

          {:keep_state, new_data,
           [{:reply, from, {:next_round, {:round, new_round, :turn, Enum.at(data.players, 0)}}}]}

        :end_game ->
          {:next_state, :ended, data, [{:reply, from, :ended}]}
      end
    else
      {:keep_state_and_data, [{:reply, from, {:error, :wrong_turn}}]}
    end
  end

  @impl true
  def handle_event({:call, from}, {:play, _, _}, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  # => :restart
  @impl true
  def handle_event({:call, from}, :restart, state, data)
      when state in [:in_play, :ended] do
    {:next_state, :in_play, do_restart(data),
     [{:reply, from, {:next_turn, {:round, 0, :turn, Enum.at(data.players, 0)}}}]}
  end

  def handle_event({:call, from}, :restart, :ended, data) do
    {:next_state, :in_play, do_restart(data),
     [{:reply, from, {:next_turn, {:round, 0, :turn, Enum.at(data.players, 0)}}}]}
  end

  @impl true
  def handle_event({:call, from}, :restart, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  # ==== #
  # Impl #
  # ==== #

  @spec do_start_round(t()) :: t()
  defp do_start_round(game) do
    Enum.each(
      game.players,
      &Player.start_round(
        &1,
        game.round,
        :rand.uniform(game.config.max_guess)
      )
    )

    game
  end

  @spec do_configure(t(), keyword()) :: t()
  defp do_configure(game, opts) do
    %Game{
      game
      | config: %Game.Configuration{max_points: Keyword.get(opts, :max_points, 300)}
    }
  end

  @spec do_add_player(t(), String.t()) :: {:ok, t()} | {:error, :player_in_game}
  defp do_add_player(game, player_name) do
    if player_in_game?(game, player_name) do
      {:error, :player_in_game}
    else
      {:ok, %__MODULE__{game | players: game.players ++ [player_name]}}
    end
  end

  @spec do_play(t(), String.t(), non_neg_integer()) ::
          :next_turn | :next_round | :end_game
  defp do_play(game, player_name, guess) do
    Player.guess(player_name, guess)

    Enum.each(
      get_bonuses(player_name, Enum.reject(game.players, &(&1 == player_name))),
      fn {points, reason} = _bonus ->
        Player.add_bonus(player_name, points, reason)
      end
    )

    Player.round_points(player_name)
    Player.total_points(player_name)

    if game.turn == length(game.players) - 1 do
      players_points =
        game.players |> Stream.map(&Player.info/1) |> Stream.map(& &1.points) |> Enum.to_list()

      if Enum.max(players_points) >= game.config.max_points do
        :end_game
      else
        :end_round
      end
    else
      :next_turn
    end
  end

  @spec do_restart(t()) :: t()
  defp do_restart(game) do
    Enum.each(game.players, &Player.reset/1)
    do_start_round(%Game{game | round: 0, turn: 0})
  end

  @spec get_bonuses(String.t(), list(String.t())) :: list(term())
  defp get_bonuses(player_name, players) do
    # TODO: I want this functionality to be more declarative.

    player_round = hd(Player.info(player_name).round_data)

    # Exact match -> guess == assigned number
    assigned_bonus =
      if player_round.guess == player_round.assigned, do: [{50, :exact_match}], else: []

    # Inverse match -> guess == reversed assigned number
    reverse_bonus =
      if length(assigned_bonus) == 0 do
        inverse_assigned =
          player_round.assigned
          |> Integer.to_string()
          |> String.reverse()
          |> String.to_integer()

        if player_round.guess == inverse_assigned, do: [{25, :reverse_match}], else: []
      else
        []
      end

    # Other match -> guess == other player assigned number
    other_bonuses =
      players
      |> Enum.map(fn p ->
        if player_round.guess == hd(Player.info(p).round_data).assigned,
          do: {25, {:other_match, Player.info(p).name}},
          else: nil
      end)
      |> Enum.reject(&is_nil/1)

    assigned_bonus ++ reverse_bonus ++ other_bonuses
  end

  # Helpers #
  defp player_in_game?(game, player_name), do: player_name in game.players

  defp is_player_turn?(game, player_name),
    do: Enum.at(game.players, game.turn, nil) == player_name
end
