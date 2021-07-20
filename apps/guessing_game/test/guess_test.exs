defmodule GuessTest do
  use ExUnit.Case
  doctest Guess

  alias Guess.{Game, Players}

  setup do
    Guess.reset()
  end

  describe "hosting a game: " do
    test "can host a new game using just the host name" do
      host_name = "HostPlayer"

      with {:ok, game} <- Guess.host(host_name),
           {_, data} <- Game.info(game) do
        assert data.host == host_name
        assert data.name == host_name
      end
    end

    test "host player is connected to server and registered with the game process" do
      host_name = "HostPlayer"

      with {:ok, game} <- Guess.host(host_name),
           {:ok, _player, game_pid} = Players.get(host_name) do
        assert game_pid == game
      end
    end

    test "can host a new game using specifying the game name as well" do
      host_name = "CoolPlayer"
      game_name = "CoolGame"

      with {:ok, game} <- Guess.host(host_name, game_name),
           {_, data} = Game.info(game) do
        assert data.host == host_name
        assert data.name == game_name
      end
    end
  end

  describe "joining a game: " do
    setup do
      host = "HostPlayer"
      {:ok, game} = Guess.host(host)
      %{game: game, host: host}
    end

    test "can join the latest game", %{game: game, host: host} do
      :ok = Guess.join("NewPlayer")

      with {_, data} <- Game.info(game) do
        assert data.players == [host, "NewPlayer"]
      end
    end

    test "can join a specified game", %{game: game, host: host} do
      new_host = "HostPlayer2"

      with {:ok, game2} <- Guess.host(new_host),
           :ok <- Guess.join("NewPlayer2", new_host),
           {_, data} <- Game.info(game),
           {_, data2} <- Game.info(game2) do
        assert data.players == [host]
        assert data2.players == [new_host, "NewPlayer2"]
      end
    end
  end

  describe "starting a game: " do
    test "host can start a game" do
      host = "Host"

      with {:ok, game} = Guess.host(host),
           :ok = Guess.join("Player"),
           {:next_turn, {:round, 0, :turn, ^host}} = Guess.start(host) do
        {state, _} = :sys.get_state(game)
        assert state == :in_play
      end
    end

    test "only the host can start a game" do
      player = "Player"

      with {:ok, _game} = Guess.host("Host"),
           :ok = Guess.join(player) do
        ans = Guess.start(player)
        assert ans == {:error, :player_not_host}
      end
    end
  end
end
