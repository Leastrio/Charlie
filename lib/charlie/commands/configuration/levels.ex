defmodule Charlie.Commands.Configuration.Levels do
  use Charlie.Command
  alias Charlie.Repo
  alias Charlie.Schema
  import Ecto.Query, only: [from: 2]

  def aliases, do: ["lvls"]
  def description, do: "Configure levels"
  def options, do: [
    %{
      type: 1,
      name: "toggle",
      description: "Toggles the level system"
    },
    %{
      type: 1,
      name: "channel",
      description: "Set the channel for the level messages",
      options: [%{type: 7, name: "channel", description: "Channel to set for level messages", channel_types: [0], required: false}]
    },
    %{
      type: 1,
      name: "message",
      description: "The level up message, (Available placeholders: {mention}, {user}, {level})",
      options: [%{type: 3, name: "message", description: "The level up message", required: true, max_length: 200}]
    },
    %{
      type: 1,
      name: "reset-all",
      description: "The reset all member's xp to 0",
    },
    %{
      type: 1,
      name: "reward",
      description: "Have the bot give the user a role when reaching a level",
      options: [
        %{type: 4, name: "level", description: "The level to reward at", required: true},
        %{type: 8, name: "role", description: "The role to reward"}
      ]
    }
  ]
  def permissions, do: [:manage_messages]
  def predicates, do: [Predicates.has_permission(:manage_messages)]

  def msg_command(msg, options) do
    resp = case options do
      ["toggle"] -> toggle_level_config(msg.guild_id)
      ["channel"] -> set_channel(msg.guild_id, nil)
      ["channel", channel_id] ->
        case check_channel(msg.guild_id, channel_id) do
          {:ok, id} -> set_channel(msg.guild_id, id)
          {:error, ret_msg} -> ret_msg
        end
      ["message" | rest] -> set_message(msg.guild_id, Enum.join(rest, " "))
      ["reset-all"] -> reset_all(msg.guild_id)
      ["reward", level] ->
        case Integer.parse(level) do
          {parsed_level, _} -> remove_reward(msg.guild_id, parsed_level)
          _ -> "Invalid level!"
        end
      ["reward", level, role] ->
        case parse_role(role) do
          {:ok, id} ->
            case Integer.parse(level) do
              {parsed_level, _} -> set_reward(msg.guild_id, parsed_level, id)
              _ -> "Invalid level!"
            end
          {:error, ret_msg} -> ret_msg
        end
      _ -> "Invalid usage! Please check the `help levels` command!"
    end
    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{name: "toggle"}]), do: [:ephemeral, {:content, toggle_level_config(interaction.guild_id)}]
  def slash_command(interaction, [%{name: "channel", options: []}]),
    do: [:ephemeral, {:content, set_channel(interaction.guild_id, nil)}]
  def slash_command(interaction, [%{name: "channel", options: [%{value: channel_id}]}]),
    do: [:ephemeral, {:content, set_channel(interaction.guild_id, channel_id)}]
  def slash_command(interaction, [%{name: "message", options: [%{value: message}]}]),
    do: [:ephemeral, {:content, set_message(interaction.guild_id, message)}]
  def slash_command(interaction, [%{name: "reset-all"}]),
    do: [:ephemeral, {:content, reset_all(interaction.guild_id)}]
  def slash_command(interaction, [%{name: "reward", options: opts}]) do
    level = Enum.find(opts, fn o -> o.name == "level" end)
    role = Enum.find(opts, nil, fn o -> o.name == "role" end)
    resp = case role do
      nil -> remove_reward(interaction.guild_id, level.value)
      _ -> set_reward(interaction.guild_id, level.value, role.value)
    end

    [:ephemeral, {:content, resp}]
  end

  def remove_reward(guild_id, level) do
    {count, _} = Repo.delete_all(from(ul in Schema.RoleReward, where: ul.guild_id == ^guild_id and ul.level_requirement == ^level))
    if count > 0 do
      "Successfully removed the reward at level #{level}"
    else
      "No reward to remove!"
    end
  end

  def set_reward(guild_id, level, role_id) do
    res = Repo.insert(%Schema.RoleReward{guild_id: guild_id, level_requirement: level, role_id: role_id}, on_conflict: [set: [role_id: role_id]], conflict_target: [:guild_id, :level_requirement])
    case res do
      {:ok, _} ->
        "Successfully set a role to reward at level #{level}"
      _ -> "An error occurred, please try again later."
    end
  end

  def parse_role(input) do
    if Regex.match?(~r/(<@)?\d{17,20}(>)?/, input) do
      parsed =
        input
        |> String.trim()
        |> String.trim_leading("<@&")
        |> String.trim_trailing(">")
        |> String.to_integer()

      {:ok, parsed}
    else
      {:error, "Invalid role"}
    end
  end

  def reset_all(guild_id) do
    {count, _} = Repo.delete_all(from(ul in Schema.UserLevel, where: ul.guild_id == ^guild_id))
    "Successfully cleared out #{count} levels!"
  end

  def set_message(guild_id, message) do
    if String.length(message) <= 200 do
      {updated, _} = Repo.update_all(from(lc in Schema.LevelConfig, where: lc.guild_id == ^guild_id), set: [level_up_message: message])
      if updated > 0 do
        "Successfully set the level up message!"
      else
        "You must toggle the level system thingy first before using this command!"
      end
    else
      "Message must be < 200 characters!"
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

  def set_channel(guild_id, channel_id) do
    res = Repo.insert(%Schema.LevelConfig{guild_id: guild_id, channel_id: channel_id}, on_conflict: [set: [channel_id: channel_id]], conflict_target: :guild_id)
    case res do
      {:ok, _} ->
        Charlie.Cache.insert_level_config(guild_id, channel_id)
        "Set the level message channel to #{if channel_id, do: "<#" <> Integer.to_string(channel_id) <> ">", else: "last channel member spoke in"}!"
      _ -> "An error occurred, please try again later."
    end
  end

  def toggle_level_config(guild_id) do
    config = Repo.get_by(Schema.LevelConfig, guild_id: guild_id)
    if is_nil(config) do
      Repo.insert(%Schema.LevelConfig{guild_id: guild_id})
      Charlie.Cache.insert_level_config(guild_id, nil)
      "Successfully toggled level system on"
    else
      changeset = Schema.LevelConfig.changeset(config, %{active: !config.active})
      case Repo.update(changeset) do
        {:ok, _} ->
          status = case config.active do
            true ->
              Charlie.Cache.delete_level_config(guild_id)
              "off"
            false ->
              Charlie.Cache.insert_level_config(guild_id, config.channel_id)
              "on"
          end
          "Successfully toggled level system #{status}"
        _ -> "Error toggling level system status"
      end
    end
  end
end
