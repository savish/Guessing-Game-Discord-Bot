defmodule Guess.Games do
  use Supervisor

  @game_registry :"Guess.GameRegistry"

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, [keys: :unique, name: @game_registry]},
      {DynamicSupervisor, name: Guess.GameSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_all]
    Supervisor.init(children, opts)
  end
end
