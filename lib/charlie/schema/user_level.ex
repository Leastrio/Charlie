defmodule Charlie.Schema.UserLevel do
  use Ecto.Schema

  @primary_key false
  schema "user_level" do
    field :guild_id, :id, primary_key: true
    field :user_id, :id, primary_key: true
    field :xp, :integer
  end  
end
