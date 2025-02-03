defmodule Charlie.Cache do
  require Logger
  alias Charlie.Repo
  alias Charlie.Schema
  import Ecto.Query

  @table_opts [
    :named_table,
    :public,
    read_concurrency: true,
    write_concurrency: true
  ]

  @tables [
    {:prefixes, :set},
    {:level_cooldowns, :bag},
    {:guild_level_configs, :set},
    {:command_invocations, :set}
  ]

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      type: :worker,
      start: {__MODULE__, :start_link, []}
    }
  end

  def start_link() do
    for {table, type} <- @tables do
      :ets.new(table, [type | @table_opts])
    end
    fill_prefixes()
    fill_level_configs()

    Logger.info("Caches created & filled")
    :ignore
  end

  defp fill_prefixes() do
    Repo.all(from(g in Schema.Guild, where: not is_nil(g.prefix), select: [g.guild_id, g.prefix]))
    |> Enum.each(fn [guild_id, prefix] -> insert_prefix(guild_id, prefix) end)
  end

  def get_prefix(guild_id) do
    case :ets.lookup(:prefixes, guild_id) do
      [{_guild_id, prefix}] -> prefix
      [] -> ","
    end
  end

  def insert_prefix(guild_id, prefix), do: :ets.insert(:prefixes, {guild_id, prefix})

  def in_cooldown(guild_id, user_id) do
    case :ets.match(:level_cooldowns, {guild_id, user_id}) do
      [[]] -> true
      _ -> false
    end
  end

  def insert_cooldown(guild_id, user_id) do
    :ets.insert(:level_cooldowns, {guild_id, user_id})
    :timer.apply_after(:timer.seconds(60), __MODULE__, :remove_cooldown, [guild_id, user_id])
  end

  def remove_cooldown(guild_id, user_id), do: :ets.match_delete(:level_cooldowns, {guild_id, user_id})

  def fill_level_configs() do
    Repo.all(from(lc in Schema.LevelConfig))
    |> Enum.each(fn lc -> insert_level_config(lc.guild_id, lc.channel_id) end)
  end

  def insert_level_config(guild_id, channel_id), do: :ets.insert(:guild_level_configs, {guild_id, channel_id})

  def get_level_config(guild_id) do
    case :ets.lookup(:guild_level_configs, guild_id) do
      [{guild_id, channel_id}] -> {guild_id, channel_id}
      [] -> nil
    end
  end

  def delete_level_config(guild_id), do: :ets.delete(:guild_level_configs, guild_id)

  def add_command_invocation(invoker_msg_id, command_msg_id) do
    :ets.insert(:command_invocations, {invoker_msg_id, command_msg_id})
    :timer.apply_after(:timer.hours(1), __MODULE__, :remove_command_invocation, invoker_msg_id)
  end

  def remove_command_invocation(invoker_msg_id), do: :ets.delete(:command_invocations, invoker_msg_id)

  def get_command_msg_id(msg_id) do
    case :ets.lookup(:command_invocations, msg_id) do
      [{_msg_id, command_msg_id}] -> 
        remove_command_invocation(msg_id)
        command_msg_id
      [] -> nil
    end
  end
end
