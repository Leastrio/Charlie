defmodule Charlie.Schema.StarboardEntry do
  use Ecto.Schema

  @primary_key false
  schema "starboard_entry" do
    field :message_id, :id, primary_key: true
    field :guild_id, :id
    field :channel_id, :id
    field :bot_message_id, :id
  end
end
