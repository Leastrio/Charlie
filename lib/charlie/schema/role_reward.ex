defmodule Charlie.Schema.RoleReward do
  use Ecto.Schema

  @primary_key false
  schema "role_reward" do
    field :guild_id, :id, primary_key: true
    field :level_requirement, :integer, primary_key: true
    field :role_id, :id
  end  
end
