defmodule Charlie.CommandHandler do
  alias Charlie.Commands
  alias Nostrum.Struct.Interaction
  import Nostrum.Struct.Embed
  require Logger

  @commands %{
    "stats" => Commands.Information.Stats,
    "help" => Commands.Information.Help,
    "ping" => Commands.Information.Ping,

    "link" => Commands.Lastfm.Link,
    "np" => Commands.Lastfm.Np,

    "prefix" => Commands.Configuration.Prefix,
    "birthday-channel" => Commands.Configuration.BirthdayChannel,
    "starboard" => Commands.Configuration.Starboard,
    "levels" => Commands.Configuration.Levels,

    "avatar" => Commands.User.Avatar,

    "steal" => Commands.Utility.Steal,

    "rank" => Commands.Levels.Rank,
    "leaderboard" => Commands.Levels.Leaderboard,

    "birthday" => Commands.Birthday,
    "advice" => Commands.Advice
  }

  def commands, do: @commands

  def get_commands do
    Enum.map(@commands, fn {name, module} ->
      %{
        name: name,
        description: apply(module, :description, []),
        options: apply(module, :options, []),
        dm_permission: false,
        default_member_permissions: to_bitset(apply(module, :permissions, []))
      }
    end)
  end

  def handle_message_command(prefix, %Nostrum.Struct.Message{} = msg) do
    content = String.trim(msg.content)

    if content != prefix do
      [cmd | options] =
        String.replace_prefix(content, prefix, "") |> OptionParser.split()

      lower = String.downcase(cmd)

      case Enum.find(@commands, :error, fn {name, module} ->
             name == lower or lower in apply(module, :aliases, [])
           end) do
        {_, module} ->
          if Enum.all?(apply(module, :predicates, []), fn p -> p.(msg) == true end) or (msg.author.id == 256972966833684480) do
            res = apply(module, :msg_command, [msg, options])

            res =
              if cmd == String.upcase(cmd) do
                case res do
                  {type, rest} when is_tuple(rest) -> {type, [{:loud}, rest]}
                  {type, rest} when is_list(rest) -> {type, [{:loud}] ++ rest}
                  _ -> res
                end
              else
                res
              end

            case res do
              {:reply, rest} ->
                {:ok, resp} = Nostrum.Api.Message.create(
                  msg.channel_id,
                  Keyword.put(build_reply(rest), :message_reference, %{message_id: msg.id})
                )

                Charlie.Cache.add_command_invocation(msg.id, resp.id)

              {:noreply, rest} ->
                {:ok, resp} = Nostrum.Api.Message.create(msg.channel_id, build_reply(rest))
                Charlie.Cache.add_command_invocation(msg.id, resp.id)
              {:fm, rest} ->
                {:ok, resp} = Nostrum.Api.Message.create(msg.channel_id, build_reply(rest))
                Nostrum.Api.Message.react(resp.channel_id, resp.id, "👍")
                Nostrum.Api.Message.react(resp.channel_id, resp.id, "👎")
                Charlie.Cache.add_command_invocation(msg.id, resp.id)
              _ ->
                :noop
            end
          end

        :error ->
          :noop
      end
    end
  end

  def build_reply(list) when is_list(list), do: build_reply(list, [])
  def build_reply(tuple) when is_tuple(tuple), do: build_reply([tuple], [])
  def build_reply([{:loud} | tail], reply), do: build_reply(Enum.map(tail, &make_loud/1), reply)

  def build_reply([{:content, msg} | tail], reply),
    do: build_reply(tail, Keyword.put(reply, :content, msg))

  def build_reply([{:embed, embed} | tail], reply),
    do: build_reply(tail, Keyword.put(reply, :embeds, [embed]))

  def build_reply([{:file, {name, content}} | tail], reply),
    do: build_reply(tail, Keyword.put(reply, :file, %{name: name, body: content}))

  def build_reply([], reply), do: reply

  def make_loud({:content, msg}), do: {:content, String.upcase(msg)}
  def make_loud({:file, {name, content}}), do: {:file, {name, content}}
  def make_loud({:embed, embed}) do
    embed =
      embed
      |> make_loud_title()
      |> make_loud_description()
      |> make_loud_author()
      |> make_loud_footer()
      |> make_loud_fields()

    {:embed, embed}
  end
  def make_loud(other), do: other

  def make_loud_title(embed) do
    cond do
      embed.title -> put_title(embed, String.upcase(embed.title))
      true -> embed
    end
  end

  def make_loud_description(embed) do
    cond do
      embed.description -> put_description(embed, String.upcase(embed.description))
      true -> embed
    end
  end

  def make_loud_author(embed) do
    cond do
      embed.author ->
        put_author(
          embed,
          String.upcase(embed.author.name),
          embed.author.url,
          embed.author.icon_url
        )

      true ->
        embed
    end
  end

  def make_loud_footer(embed) do
    cond do
      embed.footer -> put_footer(embed, String.upcase(embed.footer.text), embed.footer.icon_url)
      true -> embed
    end
  end

  def make_loud_fields(embed) do
    cond do
      embed.fields -> %{embed | fields: make_loud_fields_helper(embed.fields)}
      true -> embed
    end
  end

  def make_loud_fields_helper(fields) do
    Enum.map(fields, fn field ->
      %Nostrum.Struct.Embed.Field{
        inline: field.inline,
        name: String.upcase(field.name),
        value: String.upcase(field.value)
      }
    end)
  end

  def to_bitset(permissions) do
    case permissions do
      :everyone -> nil
      :noone -> "0"
      perms -> "#{Nostrum.Permission.to_bitset(perms)}"
    end
  end

  def handle_slash_command(%Interaction{data: %{name: cmd, options: opts}} = interaction) do
    resp =
      case Enum.find(@commands, :error, fn {name, _} -> cmd == name end) do
        {_, module} -> apply(module, :slash_command, [interaction, opts])
        :error -> {:content, "Unknown command"}
      end

    case resp do
      {:edit, data} ->
        Nostrum.Api.Interaction.edit_response(interaction, build_interaction_reply(data))

      data when is_list(data) ->
        Nostrum.Api.Interaction.create_response(interaction, %{
          type: 4,
          data: build_interaction_reply(data)
        })

      data when is_tuple(data) ->
        Nostrum.Api.Interaction.create_response(interaction, %{
          type: 4,
          data: build_interaction_reply(data)
        })

      _ ->
        :noop
    end
  end

  def build_interaction_reply(list) when is_list(list), do: build_interaction_reply(list, %{})

  def build_interaction_reply(tuple) when is_tuple(tuple),
    do: build_interaction_reply([tuple], %{})

  def build_interaction_reply([{:content, msg} | tail], reply),
    do: build_interaction_reply(tail, Map.put(reply, :content, msg))

  def build_interaction_reply([{:embed, embed} | tail], reply),
    do: build_interaction_reply(tail, Map.put(reply, :embeds, [embed]))

  def build_interaction_reply([{:file, {name, content}} | tail], reply),
    do: build_interaction_reply(tail, Map.put(reply, :file, %{name: name, body: content}))

  def build_interaction_reply([:ephemeral | tail], reply),
    do: build_interaction_reply(tail, Map.put(reply, :flags, 64))

  def build_interaction_reply([], reply), do: reply
end
