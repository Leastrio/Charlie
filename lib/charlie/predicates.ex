defmodule Charlie.Predicates do
  def has_permission(permission) do
    fn msg ->
      guild = Nostrum.Cache.GuildCache.get!(msg.guild_id)
      member_perms = Nostrum.Struct.Guild.Member.guild_permissions(msg.member, guild)
      permission in member_perms or :administrator in member_perms or msg.author.id == guild.owner_id
    end
  end
end
