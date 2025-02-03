defmodule Charlie.Schema.LevelConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "level_config" do
    field :guild_id, :id, primary_key: true
    field :channel_id, :id
    field :level_up_message, :string
    field :active, :boolean, default: true
  end  

  def changeset(config, params \\ %{}) do
    config
    |> cast(params, [:guild_id, :channel_id, :level_up_message, :active])
  end
end
