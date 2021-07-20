defmodule Bot.Application do
  @moduledoc false
  use Application
  alias Alchemy.Client

  def start(_type, _args) do
    token = Application.fetch_env!(:discord_bot, :token)
    run = Client.start(token)
    use Bot.Commands
    run
  end
end
