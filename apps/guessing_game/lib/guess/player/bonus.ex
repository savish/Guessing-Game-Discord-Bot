defmodule Guess.Player.Bonus do
  @moduledoc """
  Functionality related to bonus points

  Certain conditions, if met, may result in the assigning of bonus points to
  players based on their guesses in a round. For instance, guessing the
  exact assigned number may result in a reward of bonus points. These bonus
  points are logged in the players' round data.

  ## Example

      iex> bonus = Guess.Player.Bonus.new(35, :exceptional)
      iex> bonus.value
      35
      iex> bonus.reason
      :exceptional
  """
  use TypedStruct

  typedstruct enforce: true do
    @typedoc "Represents a point bonus assigned to a player in a round"

    field :value, non_neg_integer
    field :reason, any()
  end

  @doc """
  Creates and returns a new point bonus struct

  ## Parameters
  - `value`: number of points assigned to the bonus
  - `reason`: a term that describes the reason for the bonus

  See `Guess.Player.Bonus` for a usage example
  """
  @spec new(non_neg_integer(), any()) :: t()
  def new(value, reason) do
    %__MODULE__{value: value, reason: reason}
  end
end
