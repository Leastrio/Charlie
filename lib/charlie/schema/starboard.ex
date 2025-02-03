defmodule Charlie.Schema.Starboard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "starboard" do
    field :guild_id, :id, primary_key: true
    field :channel_id, :id
    field :threshold, :integer, default: 5
    field :active, :boolean, default: true
  end

  def changeset(config, params \\ %{}) do
    config
    |> cast(params, [:guild_id, :channel_id, :threshold, :active])
  end
end
