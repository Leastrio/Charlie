defmodule Charlie.Schema.Birthday do
  use Ecto.Schema

  @primary_key false
  schema "birthday" do
    field :guild_id, :id, primary_key: true
    field :user_id, :id, primary_key: true
    field :month, :integer
    field :day, :integer
    field :year, :integer
  end
end
