defmodule Charlie.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table("guild", primary_key: false) do
      add :guild_id, :bigint, primary_key: true
      add :prefix, :string, size: 10
      add :birthday_channel_id, :bigint
    end

    create table("starboard", primary_key: false) do
      add :guild_id, :bigint, primary_key: true
      add :channel_id, :bigint, null: false
      add :threshold, :smallint, null: false, default: 5
      add :active, :boolean, default: true
    end

    create table("starboard_entry", primary_key: false) do
      add :message_id, :bigint, primary_key: true
      add :guild_id, references("starboard", column: :guild_id, type: :bigint, on_delete: :delete_all), null: false
      add :channel_id, :bigint, null: false
      add :bot_message_id, :bigint, null: false
    end

    create table("birthday", primary_key: false) do
      add :guild_id, references("guild", column: :guild_id, type: :bigint, on_delete: :delete_all), primary_key: true
      add :user_id, :bigint, primary_key: true
      add :month, :smallint, null: false
      add :day, :smallint, null: false
      add :year, :smallint
    end

    create table(:user, primary_key: false) do
      add :user_id, :bigint, primary_key: true
      add :lastfm_username, :string
    end

    create table(:level_config, primary_key: false) do
      add :guild_id, :bigint, primary_key: true
      add :channel_id, :bigint
      add :level_up_message, :string
      add :active, :boolean, default: true
    end

    create table(:user_level, primary_key: false) do
      add :guild_id, references("level_config", column: :guild_id, type: :bigint, on_delete: :delete_all), primary_key: true
      add :user_id, :bigint, primary_key: true
      add :xp, :integer, null: false
    end

    create table(:role_reward, primary_key: false) do
      add :guild_id, references("level_config", column: :guild_id, type: :bigint, on_delete: :delete_all), primary_key: true
      add :level_requirement, :integer, primary_key: true
      add :role_id, :bigint, null: false
    end
  end
end
