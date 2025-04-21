import Config

config :charlie, Charlie.Repo,
  database: "charlie",
  username: "charlie",
  password: "password",
  hostname: "127.0.0.1",
  port: 5433

config :charlie,
  ecto_repos: [Charlie.Repo]

config :nostrum,
  num_shards: :auto,
  gateway_intents: [
    :message_content,
    :guild_messages,
    :guilds,
    :guild_message_reactions,
    :guild_members
  ],
  caches: %{
    guilds: Nostrum.Cache.GuildCache.Mnesia,
    members: Nostrum.Cache.MemberCache.Mnesia,
    users: Nostrum.Cache.UserCache.Mnesia,
    channels: Nostrum.Cache.ChannelCache.NoOp,
    presences: Nostrum.Cache.PresenceCache.NoOp
  },
  request_guild_members: true,
  youtubedl: nil,
  streamlink: nil

config :logger,
  level: :info
