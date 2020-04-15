defmodule Guess.Game.Server do
  use GenStateMachine

  alias Guess.Game.Impl
  alias Guess.Game.Server
  alias GenStateMachine, as: GSM

  # Callbacks #
  @impl true
  def handle_event({:call, from}, :summary, state, data) do
    {:keep_state_and_data, [{:reply, from, Impl.summary({state, data})}]}
  end

  @impl true
  def handle_event({:call, from}, :players, _state, data) do
    {:keep_state_and_data, [{:reply, from, Impl.players(data)}]}
  end

  @impl true
  def handle_event({:call, from}, {:join, player_name}, :setting_up, data) do
    {:keep_state, Impl.join(data, player_name), [{:reply, from, :ok}]}
  end

  @impl true
  def handle_event({:call, from}, {:join, _}, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  @impl true
  def handle_event({:call, from}, :start, :setting_up, data) do
    new_data = Impl.start(data)
    round_turn = round_turn(new_data)
    next_state = {:round, new_data.round, :turn, data.players |> Enum.at(round_turn)}

    {:next_state, next_state, new_data, [{:reply, from, {:ok, next_state}}]}
  end

  @impl true
  def handle_event({:call, from}, :start, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_action_for_state}}]}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:play, player_name, guess},
        {:round, _, :turn, player_turn},
        data
      )
      when player_name == player_turn do
    new_data = Impl.end_turn(data, player_name, guess)
    round_turn = round_turn(new_data)

    {next_state, new_data, reply} =
      if round_turn == 0 do
        new_data = Impl.end_round(new_data)

        next_state =
          if Impl.is_game_over?(new_data),
            do: :ended,
            else: {:round, new_data.round, :turn, data.players |> Enum.at(round_turn)}

        reply = {:end_round, {next_state, new_data.points}}
        {next_state, new_data, reply}
      else
        next_state = {:round, new_data.round, :turn, data.players |> Enum.at(round_turn)}
        reply = {:end_turn, next_state}
        {next_state, new_data, reply}
      end

    {:next_state, next_state, new_data, [{:reply, from, reply}]}
  end

  @impl true
  def handle_event({:call, from}, {:play, _, _}, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :not_your_turn}}]}
  end

  # Supervisor API #
  def start_link(opts) do
    host = Keyword.fetch!(opts, :host)
    GSM.start_link(Server, Impl.new(host))
  end

  # Private #
  def round_turn(data) do
    data.turn_order
    |> Enum.at(rem(data.absolute_turn, length(data.players)))
  end
end
