defmodule Charlie.Schema.User do
  use Ecto.Schema

  @primary_key false
  schema "user" do
    field :user_id, :id, primary_key: true
    field :lastfm_username, :string
  end  
end
