defmodule Guess.PlayerTest do
  use ExUnit.Case
  alias Guess.Player
  alias Guess.Game
  doctest Guess.Player

  describe "player details:" do
    setup [:create_player]

    test "can retrieve player info", %{host: host} do
      %Player{game: game, is_host: is_host, name: player_name} = Player.info(host)
      assert {player_name, is_host, game} == {host, false, nil}
    end
  end

  describe "server actions:" do
    setup [:create_player, :host_game]

    test "can get the game the player is in", %{host: host, game: game} do
      {:ok, hosted_game} = Player.get_game(host)
      assert hosted_game == game
    end

    test "can start a game if host", %{host: host} do
      {:ok, {:round, round, :turn, turn}} = Player.start_game(host)
      assert {round, turn} == {1, host}
    end

    test "can play a game turn", %{host: host} do
      Player.start_game(host)
      {:end_round, {{:round, round, :turn, turn}, _points}} = Player.play(host, 12)
      assert {round, turn} == {2, host}
    end

    test "can leave a game", %{host: host} do
      ans = Player.leave_game(host)
      assert ans == :ok
    end
  end

  # TODO: Figure out how to test joined player actions

  defp create_player(_context) do
    host = "Host"
    player = start_supervised!({Player.Server, [name: host]}, id: host)
    %{player: player, host: host}
  end

  defp host_game(context) do
    %{host: host} = context
    game = start_supervised!({Game.Server, [host: host]})
    Player.host_game(host, game)
    Map.put_new(context, :game, game)
  end
end
