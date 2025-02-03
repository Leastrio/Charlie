defmodule Charlie.Levels do
  import Ecto.Query, only: [from: 2]
  alias Charlie.Repo
  alias Charlie.Schema

  def handle(%Nostrum.Struct.Message{} = msg) do
    config = Charlie.Cache.get_level_config(msg.guild_id)
    if not is_nil(config) do
      if not Charlie.Cache.in_cooldown(msg.guild_id, msg.author.id) do
        Charlie.Cache.insert_cooldown(msg.guild_id, msg.author.id)
        add_xp(msg, config, gen_xp())
      end
    end
  end

  def add_xp(msg, {_, config_channel_id}, xp) do
    member = Repo.insert!(
      %Schema.UserLevel{guild_id: msg.guild_id, user_id: msg.author.id, xp: xp},
      on_conflict: [inc: [xp: xp]],
      conflict_target: [:guild_id, :user_id],
      returning: [:xp]
    )
    old_level = calc_level(member.xp - xp)
    new_level = calc_level(member.xp)

    if new_level > old_level do
      channel_id = case config_channel_id do
        nil -> msg.channel_id
        id -> id
      end

      level_message = gen_level_message(Repo.one!(from(lc in Schema.LevelConfig, where: lc.guild_id == ^msg.guild_id, select: lc.level_up_message)), msg.guild_id, msg.author.id, new_level)

      Nostrum.Api.Message.create(channel_id, content: level_message, allowed_mentions: {:users, [msg.author.id]})

      reward = Repo.one(from(rr in Schema.RoleReward, where: rr.guild_id == ^msg.guild_id and rr.level_requirement == ^new_level))

      if !is_nil(reward) do
        case Nostrum.Api.Guild.add_member_role(
          msg.guild_id,
          msg.author.id,
          reward.role_id,
          "Automatic role adding, level #{new_level}"
        ) do
          {:ok} -> :ok
          _ -> "An error occurred while trying to give you a role reward. Make sure my role is above the role reward!"
          end
      end
    end
  end

  def gen_xp do
    Enum.random(15..25)
  end

  def calc_level(xp), do: calc_level(xp, {0, 0})

  def calc_level(xp, {level, temp_xp}) do
    if xp >= temp_xp do
      calc_level(xp, {level + 1, xp_for_level(level + 1)})
    else
      level - 1
    end
  end

  def xp_for_level(level) do
    5.0 / 6.0 * level * (2.0 * level * level + 27.0 * level + 91.0)
  end

  def gen_level_message(conf_message, guild_id, user_id, level) do
    template = case conf_message do
      nil -> "{mention} leveled up to level {level}!"
      custom -> custom
    end

    Regex.replace(~r/({mention}|{user}|{level})/, template, fn _, match -> 
      case match do
        "{mention}" -> "<@#{user_id}>"
        "{user}" -> 
          {_, user} = Nostrum.Cache.MemberCache.get_with_user(guild_id, user_id)
          user.global_name || user.username
        "{level}" -> Integer.to_string(level)
      end
    end)
  end
end
