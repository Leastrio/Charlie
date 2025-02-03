defmodule Charlie.Schema.Guild do
  use Ecto.Schema

  @primary_key false
  schema "guild" do
    field :guild_id, :id, primary_key: true
    field :prefix, :string
    field :birthday_channel_id, :id
  end
end
