defmodule Guess.Players do
  use Supervisor

  @player_registry :"Guess.PlayerRegistry"

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, [keys: :unique, name: @player_registry]},
      {DynamicSupervisor, name: Guess.PlayerSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_all]
    Supervisor.init(children, opts)
  end
end
