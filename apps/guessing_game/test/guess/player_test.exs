defmodule Guess.PlayerTest do
  use ExUnit.Case
  doctest Guess.Player
  doctest Guess.Player.Bonus
  doctest Guess.Player.Round
  alias Guess.Player
  alias Guess.Player.{Bonus, Round}

  setup do
    Guess.reset()
    player = start_supervised!({Player, name: "test player"})
    %{player: player, name: "test player"}
  end

  test "can get newly created player info", %{name: name} do
    with info <- Player.info(name) do
      assert info.name == name
      assert info.points == 0
      assert info.round_data == []
    end
  end

  test "can start a new round for a player", %{name: name} do
    {round_num, assigned} = {1, 42}

    with :ok <- Player.start_round(name, round_num, assigned),
         info <- Player.info(name) do
      assert length(info.round_data) == 1

      round = hd(info.round_data)
      assert round.assigned == assigned
      assert round.round == round_num
      assert round.guess == nil
      assert round.points == nil
      assert round.bonuses == []
    end
  end

  test "can record a player's guess", %{name: name} do
    {round_num, assigned, guessed} = {0, 42, 43}

    with :ok <- Player.start_round(name, round_num, assigned),
         :ok <- Player.guess(name, guessed),
         info <- Player.info(name),
         round <- hd(info.round_data) do
      assert round.assigned == assigned
      assert round.round == round_num
      assert round.guess == guessed
      assert round.points == nil
      assert round.bonuses == []
    end
  end

  test "can add bonus points for the round", %{name: name} do
    {round_num, assigned, guessed} = {0, 42, 24}

    with :ok <- Player.start_round(name, round_num, assigned),
         :ok <- Player.guess(name, guessed),
         :ok <- Player.add_bonus(name, 25, :inverse_match),
         info <- Player.info(name),
         round <- hd(info.round_data) do
      assert round.assigned == assigned
      assert round.round == round_num
      assert round.guess == guessed
      assert round.points == nil
      assert round.bonuses == [%Bonus{reason: :inverse_match, value: 25}]
    end
  end

  test "can calculate point values for the round", %{name: name} do
    {round_num, assigned, guessed, bval, breason} = {0, 42, 24, 25, :inverse_match}
    difference = 100 - abs(guessed - assigned)
    points = difference + bval

    with :ok <- Player.start_round(name, round_num, assigned),
         :ok <- Player.guess(name, guessed),
         :ok <- Player.add_bonus(name, bval, breason),
         :ok <- Player.round_points(name),
         info <- Player.info(name),
         round <- hd(info.round_data) do
      assert round.assigned == assigned
      assert round.round == round_num
      assert round.guess == guessed
      assert round.points == points
      assert round.bonuses == [%Bonus{reason: breason, value: bval}]
    end
  end

  test "can calculate total points for the player", %{name: name} do
    {round_num, assigned, guessed, bval, breason} = {0, 42, 24, 25, :inverse_match}
    difference = 100 - abs(guessed - assigned)
    points = difference + bval

    with :ok <- Player.start_round(name, round_num, assigned),
         :ok <- Player.guess(name, guessed),
         :ok <- Player.add_bonus(name, bval, breason),
         :ok <- Player.round_points(name),
         :ok <- Player.total_points(name),
         info <- Player.info(name) do
      assert info.points == points
    end
  end

  test "can completely reset a player", %{name: name} do
    {round_num, assigned} = {0, 42}

    with :ok <- Player.start_round(name, round_num, assigned),
         :ok <- Player.reset(name),
         info <- Player.info(name) do
      assert info.name == name
      assert info.points == 0
      assert info.round_data == []
    end
  end
end
