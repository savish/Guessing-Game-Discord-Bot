defmodule Guess.Player.Impl do
  alias Guess.Player

  @spec new(String.t()) :: Player.t()
  def new(name) do
    %Player{
      name: name
    }
  end

  @spec host_game(Player.t(), any) :: Player.t()
  def host_game(data, game) do
    %Player{data | game: game, is_host: true}
  end

  @spec join_game(Player.t(), any) :: Player.t()
  def join_game(data, game) do
    %Player{data | game: game}
  end

  @spec leave_game(Player.t()) :: Player.t()
  def leave_game(data) do
    %Player{data | game: nil, is_host: false}
  end
end
