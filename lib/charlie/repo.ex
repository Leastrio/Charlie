defmodule Charlie.Repo do
  use Ecto.Repo,
    otp_app: :charlie,
    adapter: Ecto.Adapters.Postgres
end
