defmodule Guess.GameTest do
  use ExUnit.Case
  alias Guess.Game
  doctest Guess.Game

  describe "game setting up:" do
    setup [:host_game]

    test "can retrieve the game's summary string", %{game: game, host: host} do
      game_summary = Game.summary(game)
      assert game_summary == "#{host}'s game: Setting up"
    end

    test "can retrieve game player list", %{game: game, host: host} do
      players = Game.players(game)
      assert players == [host]
    end

    test "player can join game", %{game: game, host: host} do
      _ = Game.join(game, "Player 3")
      players = Game.players(game)
      assert players == [host, "Player 3"]
    end

    test "game can be started", %{game: game, host: host} do
      Game.start(game)
      {{:round, round, :turn, turn}, _data} = :sys.get_state(game)
      assert {round, turn} == {1, host}
    end

    test "player cannot make a guess", %{game: game, host: host} do
      play_result = Game.play(game, host, 12)
      assert play_result == {:error, :invalid_action_for_state}
    end
  end

  describe "game ongoing:" do
    setup [:host_game, :join_game, :start_game]

    test "players can't join an ongoing game", %{game: game} do
      join_result = Game.join(game, "Player 4")
      assert join_result == {:error, :invalid_action_for_state}
    end

    test "players can make a guess during their turns", %{game: game, host: host, p2: p2} do
      {:end_turn, {:round, round, :turn, turn}} = Game.play(game, host, 12)
      assert {round, turn} == {1, p2}
    end

    test "players guesses must be within bounds", %{game: game, host: host} do
      play_result = Game.play(game, host, 102)
      assert play_result == {:error, :out_of_bounds}
    end

    test "players can only make a guess during their turns", %{game: game, p2: p2} do
      play_result = Game.play(game, p2, 12)
      assert play_result == {:error, :not_your_turn}
    end

    test "resets the round correctly", %{game: game, host: host, p2: p2, p3: p3} do
      Game.play(game, host, 12)
      Game.play(game, p2, 13)
      {:end_round, {{:round, round, :turn, turn}, _points}} = Game.play(game, p3, 14)
      assert {round, turn} == {2, host}
    end

    # TODO: To test game end, the top-points value needs to be configurable
  end

  describe "game ended:" do
    # TODO: Depends on configurable top-points
    # test "players can leave the game" do
    #   assert false
    # end

    # test "players can't make guesses" do
    #   assert false
    # end
  end

  defp host_game(_context) do
    host = "Host"
    game = start_supervised!({Game.Server, [host: host]})
    %{game: game, host: host, p2: "Player 2"}
  end

  defp join_game(context) do
    p3 = "Player 3"
    %{game: game, p2: p2} = context
    Game.join(game, p2)
    Game.join(game, p3)
    Map.put_new(context, :p3, p3)
  end

  defp start_game(context) do
    %{game: game} = context
    Game.start(game)
    context
  end
end
