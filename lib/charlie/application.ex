defmodule Charlie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Charlie.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:charlie, :ecto_repos)},
      Charlie.Cache,
      Charlie.Consumer,
      Charlie.StatusRotator,
      Charlie.Birthday
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Charlie.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
