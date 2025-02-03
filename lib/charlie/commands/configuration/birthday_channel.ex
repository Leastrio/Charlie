defmodule Charlie.Commands.Configuration.BirthdayChannel do
  use Charlie.Command
  import Ecto.Query, only: [from: 2]

  def aliases, do: ["bdaych"]
  def description, do: "Setup or change a birthday channel for the bot to send birthday messages!"
  def options, do: [
    %{
      type: 1,
      name: "remove",
      description: "Remove the starboard (Does not delete the channel)"
    },
    %{
      type: 1,
      name: "set",
      description: "Setup the birthday channel",
      options: [
        %{
          type: 7,
          name: "channel",
          description: "The starboard channel",
          channel_types: [0],
          required: true
        }
      ]
    }
  ]
  def permissions, do: [:manage_guild]
  def predicates, do: [Predicates.has_permission(:manage_guild)]

  def msg_command(msg, options) do
    resp = case options do
      ["remove"] -> remove_bday_channel(msg.guild_id)
      ["set", channel] ->
        case check_channel(msg.guild_id, channel) do
          {:ok, channel_id} -> set_bday_channel(msg.guild_id, channel_id)
          {:error, ret_msg} -> ret_msg
        end
      _ -> "Invalid usage! ex. `,birthday-channel (set|remove) (#channel)`"
    end

    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{name: "remove"}]), do: [:ephemeral, {:content, remove_bday_channel(interaction.guild_id)}]

  def slash_command(interaction, [%{name: "set", options: [%{value: channel}]}]), do: [:ephemeral, {:content, set_bday_channel(interaction.guild_id, channel)}]

  def remove_bday_channel(guild_id) do
    {updated, _} = Charlie.Repo.update_all(from(g in Charlie.Schema.Guild, where: g.guild_id == ^guild_id and (not is_nil(g.birthday_channel_id))), set: [birthday_channel_id: nil])
    if updated > 0 do
      "Removed birthday channel"
    else
      "A birthday channel was not set in this server!"
    end
  end

  def check_channel(guild_id, channel) do
    case parse_channel(guild_id, channel) do
      {:ok, cached_channel} -> case cached_channel.type do
        0 -> {:ok, cached_channel.id}
        _ -> {:error, "Invalid channel type, channel mentioned must be a text channel!"}
      end
      _ -> {:error, "Invalid channel!"}
    end
  end

  def set_bday_channel(guild_id, channel_id) do
    %Charlie.Schema.Guild{guild_id: guild_id, birthday_channel_id: channel_id}
    |> Charlie.Repo.insert(on_conflict: [set: [birthday_channel_id: channel_id]], conflict_target: :guild_id)

    "A birthday channel has been setup at <##{channel_id}>!"
  end
end
