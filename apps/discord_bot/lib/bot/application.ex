defmodule Bot.Application do
  @moduledoc false
  use Application
  alias Alchemy.Client
  alias Guess.Server

  defmodule Commands do
    use Alchemy.Cogs

    Cogs.def help() do
      help = """
      ```
      Welcome to the Guessing Game!
      ==

      # Controls

      - !connect (?name) connect to the game server.
      ```
      """

      Cogs.say(help)
    end

    Cogs.def connect(player_name) do
      Cogs.say(player_name |> connnect_to_server() |> response_fmt())
    end

    Cogs.def connect() do
      Cogs.say(
        Cogs.member()
        |> get_discord_name()
        |> connnect_to_server()
        |> response_fmt()
      )
    end

    Cogs.def dc(player_name) do
      Cogs.say(player_name |> disconnect_from_server() |> response_fmt())
    end

    Cogs.def dc() do
      Cogs.say(Cogs.member() |> get_discord_name() |> disconnect_from_server() |> response_fmt())
    end

    Cogs.def players() do
      {:ok, resp_arr} = Server.list_players()

      response =
        resp_arr
        |> Enum.with_index(1)
        |> Enum.map(fn {index, player} -> "#{player}. #{index}" end)
        |> Enum.join("\n")

      Cogs.say(response)
    end

    Cogs.def games() do
      {:ok, resp_arr} = Server.list_games()

      response =
        resp_arr
        |> Enum.with_index(1)
        |> Enum.map(fn {index, game} -> "#{game}. #{index}" end)
        |> Enum.join("\n")

      Cogs.say(response)
    end

    Cogs.def host() do
      {:ok, %Alchemy.Guild.GuildMember{user: %Alchemy.User{username: username}}} = Cogs.member()

      response =
        case Server.host_game(username) do
          {:error, _} -> "Unable to host game"
          _ -> "Game hosted"
        end

      Cogs.say(response)
    end

    ## Private

    @spec response_fmt(String.t()) :: String.t()
    defp response_fmt(resp) do
      # Wraps the response in a code block
      "```#{resp}```"
    end

    defp get_discord_name(member) do
      {:ok, %Alchemy.Guild.GuildMember{user: %Alchemy.User{username: player_name}}} = member

      player_name
    end

    @spec connnect_to_server(String.t()) :: String.t()
    defp connnect_to_server(player_name) do
      case Server.join(player_name) do
        {:error, :player_name_taken} ->
          "Player name taken! Please choose another using '!connect <<name>>'"

        {:error, reason} ->
          to_string(reason)

        _ ->
          "Successfully connected to the Guessing Game server, #{player_name}!"
      end
    end

    @spec disconnect_from_server(String.t()) :: String.t()
    defp disconnect_from_server(player_name) do
      case Server.leave(player_name) do
        {:error, :player_doesnt_exist} ->
          "#{player_name} is not connected to this server"

        :ok ->
          "#{player_name} has left the server."
      end
    end
  end

  def start(_type, _args) do
    token = Application.fetch_env!(:discord_bot, :token)
    run = Client.start(token)
    use Commands
    run
  end
end
