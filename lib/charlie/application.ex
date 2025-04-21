defmodule Charlie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    bot_options = %{
      consumer: Charlie.Consumer,
      intents: [
        :message_content,
        :guild_messages,
        :guilds,
        :guild_message_reactions,
        :guild_members
      ],
      wrapped_token: fn -> System.get_env("BOT_TOKEN") end,
      num_shards: :auto
    }

    children = [
      Charlie.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:charlie, :ecto_repos)},
      Charlie.Cache,
      {Nostrum.Bot, bot_options},
      Charlie.StatusRotator,
      Charlie.Birthday
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Charlie.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
