defmodule Charlie.Commands.Configuration.Starboard do
  use Charlie.Command
  alias Charlie.Repo
  alias Charlie.Schema
  import Ecto.Query, only: [from: 2]

  def aliases, do: ["sb"]
  def description, do: "Configure the starboard"
  def options, do: [
    %{
      type: 1,
      name: "remove",
      description: "Removes the starboard. Does not delete the channel but deletes all info from the bot."
    },
    %{
      type: 1,
      name: "toggle",
      description: "Toggles the starboard"
    },
    %{
      type: 1,
      name: "channel",
      description: "Set the channel for the starboard",
      options: [%{type: 7, name: "channel", description: "The starboard channel to set", channel_types: [0], required: true}]
    },
    %{
      type: 1,
      name: "threshold",
      description: "The minimum number of stars a message needs before it gets put up on the starboard",
      options: [%{type: 4, name: "threshold", description: "Minimum number of stars", required: true}]
    }
  ]
  def permissions, do: [:manage_messages]
  def predicates, do: [Predicates.has_permission(:manage_messages)]

  def msg_command(msg, options) do
    resp = case options do
      ["remove"] -> remove_starboard(msg.guild_id)
      ["toggle"] -> toggle_starboard(msg.guild_id)
      ["channel", channel] -> 
        case check_channel(msg.guild_id, channel) do
          {:ok, id} -> set_channel(msg.guild_id, id)
          {:error, ret_msg} -> ret_msg
        end
      ["threshold", threshold] -> set_threshold(msg.guild_id, threshold)
      ["min", threshold] -> set_threshold(msg.guild_id, threshold)
      _ -> "Invalid usage!"
    end

    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{name: "remove"}]), do: [:ephemeral, {:content, remove_starboard(interaction.guild_id)}]
  def slash_command(interaction, [%{name: "toggle"}]), do: [:ephemeral, {:content, toggle_starboard(interaction.guild_id)}]
  def slash_command(interaction, [%{name: "channel", options: [%{value: channel_id}]}]),
    do: [:ephemeral, {:content, set_channel(interaction.guild_id, channel_id)}]
  def slash_command(interaction, [%{name: "threshold", options: [%{value: threshold}]}]),
    do: [:ephemeral, {:content, set_threshold(interaction.guild_id, threshold)}]

  def check_channel(guild_id, channel) do
    case parse_channel(guild_id, channel) do
      {:ok, cached_channel} -> case cached_channel.type do
        0 -> {:ok, cached_channel.id}
        _ -> {:error, "Invalid channel type, channel mentioned must be a text channel!"}
      end
      _ -> {:error, "Invalid channel!"}
    end
  end
  
  def parse_threshold(threshold) when is_integer(threshold) do
    case check_threshold(threshold) do
      :ok -> {:ok, threshold}
      _ -> {:error, "Threshold out of range"}
    end
  end

  def parse_threshold(threshold) do
    case Integer.parse(threshold) do
      {min, _} -> parse_threshold(min)
      _ -> {:error, "Invalid number!"}
    end
  end


  def check_threshold(threshold) do
    if threshold > 0 and threshold < 32767 do
      :ok
    else
      :error
    end
  end

  def remove_starboard(guild_id) do
    {deleted, _} = Repo.delete_all(from(sc in Schema.Starboard, where: sc.guild_id == ^guild_id))
    if deleted > 0 do
      "Removed starboard"
    else
      "The starboard in this server is not setup!"
    end
  end

  def set_channel(guild_id, channel_id) do
    res = Repo.insert(%Schema.Starboard{guild_id: guild_id, channel_id: channel_id}, on_conflict: [set: [channel_id: channel_id]], conflict_target: :guild_id)
    case res do
      {:ok, _} -> "Set the starboard channel to <##{channel_id}>!"
      _ -> "An error occurred, please try again later."
    end
  end

  def set_threshold(guild_id, threshold) do
    case parse_threshold(threshold) do
      {:ok, min} ->
        {updated, _} = Repo.update_all(from(sc in Schema.Starboard, where: sc.guild_id == ^guild_id), set: [threshold: min])
        if updated > 0 do
          "Set the minimum star threshold to #{threshold}"
        else
          "You must setup the starboard's channel first to use this command!"
        end
      {:error, ret_msg} -> ret_msg
    end
  end

  def toggle_starboard(guild_id) do
    config = Repo.get_by(Schema.Starboard, guild_id: guild_id)
    if is_nil(config) do
      "The starboard in this server has not been setup yet!"
    else
      changeset = Schema.Starboard.changeset(config, %{active: !config.active})
      case Repo.update(changeset) do
        {:ok, _} -> "Successfully toggled starboard to #{if config.active, do: "off", else: "on"}"
        _ -> "Error toggling starboard status"
      end
    end
  end

end
