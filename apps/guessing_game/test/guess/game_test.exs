defmodule Guess.GameTest do
  use ExUnit.Case
  doctest Guess.Game
  doctest Guess.Game.Configuration
  alias Guess.{Game, Player}
  alias Guess.Game.Configuration

  setup do
    Guess.reset()
    host = "host"
    name = "game"
    game = start_supervised!({Game, host: host, name: name})

    %{
      game: game,
      name: name,
      host: host
    }
  end

  test "can get newly created game info", %{game: game, name: name, host: host} do
    with {state, game} <- Game.info(game) do
      assert state == :setting_up

      assert game == %Game{
               config: %Configuration{},
               host: host,
               name: name,
               players: [host],
               round: 0,
               turn: 0
             }
    end
  end
end
