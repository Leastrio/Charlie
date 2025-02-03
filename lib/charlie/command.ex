defmodule Charlie.Command do
  @callback aliases :: [String.t()]
  @callback options :: [Nostrum.Struct.ApplicationCommand.command_option()]
  @callback description :: String.t()
  @callback permissions :: :everyone | :noone | [Nostrum.Permission.t()]
  @callback predicates :: [...]

  defmacro __using__(_) do
    quote do
      @behaviour Charlie.Command
      import Charlie.Command, only: [parse_user: 2, parse_time: 1, parse_channel: 2]
      alias Charlie.Predicates
    end
  end

  def parse_user(guild_id, input) do
    cond do
      Regex.match?(~r/(<@)\d{17,20}(>)/, input) ->
        parsed =
          input
          |> String.trim()
          |> String.trim_leading("<@")
          |> String.trim_trailing(">")
          |> String.to_integer()

        case Nostrum.Cache.MemberCache.get_with_user(guild_id, parsed) do
          nil -> {parsed, nil}
          {member, user} -> {parsed, {member, user}}
        end

      Regex.match?(~r/\d{17,20}/, input) ->
        parsed =
          input
          |> String.trim()
          |> String.to_integer()

        case Nostrum.Cache.MemberCache.get_with_user(guild_id, parsed) do
          nil -> {parsed, nil}
          {member, user} -> {parsed, {member, user}}
        end

      true ->
        case Nostrum.Cache.MemberCache.fold_with_users(nil, guild_id, fn {member, user}, acc ->
               if user.username == input do
                 {member, user}
               else
                 acc
               end
             end) do
          nil -> :error
          {member, user} -> {user.id, {member, user}}
        end
    end
  end

  def parse_channel(guild_id, input) do
    if Regex.match?(~r/(<#)\d{17,20}(>)/, input) do
      parsed =
        input
        |> String.trim()
        |> String.trim_leading("<#")
        |> String.trim_trailing(">")
        |> String.to_integer()

      case Nostrum.Cache.GuildCache.get(guild_id) do
        {:ok, guild} -> find_channel(guild, parsed)
        _ -> {:error, parsed}
      end
    else
      :error
    end
  end

  defp find_channel(guild, channel_id) do
    case Enum.find(guild.channels, nil, fn {id, _} -> id == channel_id end) do
      nil -> {:error, channel_id}
      {_, channel} -> {:ok, channel}
    end
  end

  def parse_time(input) do
    case Regex.named_captures(~r/(?<number>\d+(\.\d+)?)(?<format>\s?(s|mo|m|h|d|w|y))/, input) do
      %{"format" => format, "number" => time} ->
        multiplier =
          case String.trim(format) do
            "s" -> 1
            "m" -> 60
            "h" -> 60 * 60
            "d" -> 60 * 60 * 24
            "w" -> 60 * 60 * 24 * 7
            "mo" -> floor(60 * 60 * 24 * 7 * 30.4167)
            "y" -> floor(60 * 60 * 24 * 7 * 30.4167 * 12)
          end

        case Integer.parse(time) do
          {parsed, _} -> parsed * multiplier
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
