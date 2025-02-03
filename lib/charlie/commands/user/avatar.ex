defmodule Charlie.Commands.User.Avatar do
  use Charlie.Command
  import Nostrum.Struct.Embed

  def aliases, do: ["av"]
  def description, do: "View a user's avatar"
  def options, do: [
    %{
      type: 6,
      name: "user",
      description: "User to get avatar",
      required: false
    }
  ]
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, options) do
    user = case options do
      [] -> {msg.member, msg.author}
      [id] -> 
        case parse_user(msg.guild_id, id) do
          {_, {member, user}} -> {member, user}
          _ -> nil
        end
    end

    resp = case user do
      nil -> {:content, "User not found!"}
      {member, user} -> {:embed, gen_embed(msg.guild_id, member, user)}
    end

    {:reply, resp}
  end

  def slash_command(interaction, nil), do: {:embed, gen_embed(interaction.guild_id, interaction.member, interaction.user)}

  def slash_command(interaction, [%{value: user_id}]) do
    user = case Nostrum.Cache.MemberCache.get_with_user(interaction.guild_id, user_id) do
      nil -> nil
      {member, user} -> {member, user}
    end

    case user do
      nil -> {:content, "User not cached, please try again later!"}
      {member, user} -> {:embed, gen_embed(interaction.guild_id, member, user)}
    end
  end

  def gen_embed(guild_id, member, user) do
    %Nostrum.Struct.Embed{}
    |> put_title("#{user.global_name || user.username}'s avatar")
    |> put_image(get_avatar(guild_id, member, user) <> "?size=1024")
  end

  def get_avatar(guild_id, member, user) do
    cond do
      member.avatar ->
        format = if String.starts_with?(member.avatar, "a_"), do: "gif", else: "png"
        URI.encode(Nostrum.Constants.cdn_url() <> "/guilds/#{guild_id}/users/#{user.id}/avatar/#{member.avatar}.#{format}")
      user.avatar ->
        format = if String.starts_with?(user.avatar, "a_"), do: "gif", else: "png"
        URI.encode(Nostrum.Constants.cdn_url() <> Nostrum.Constants.cdn_avatar(user.id, user.avatar, format))
      true ->
        img_name = case user.discriminator do
          "0" -> Bitwise.bsr(user.id, 22) |> rem(6)
          disc -> String.to_integer(disc) |> rem(5)
        end
        URI.encode(Nostrum.Constants.cdn_url() <> Nostrum.Constants.cdn_embed_avatar(img_name))
    end
  end
end
