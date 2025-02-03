import Config

config :nostrum,
  token: System.get_env("BOT_TOKEN")

config :charlie,
  lastfm_api_key: System.get_env("LASTFM_API_KEY")
