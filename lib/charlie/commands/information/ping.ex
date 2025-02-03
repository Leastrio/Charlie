defmodule Charlie.Commands.Information.Ping do
  use Charlie.Command
  import Bitwise
  import Nostrum.Struct.Embed

  def aliases, do: []
  def description, do: "Shows the current shard gateway latency"
  def options, do: []
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, _) do
    {:reply, {:embed, gen_embed(msg.guild_id)}}
  end

  def slash_command(interaction, _) do
    {:embed, gen_embed(interaction.guild_id)}
  end

  def gen_embed(guild_id) do
    shard = calc_shard(guild_id)
    curr_ping = get_ping(shard)
    %Nostrum.Struct.Embed{}
    |> put_title("Charlie Ping")
    |> put_description("Shard Num: #{shard}\nGateway Ping: #{curr_ping}ms")
    |> put_color(0x77dd77)
  end

  def calc_shard(guild_id) do
    {_url, shards} = Nostrum.Util.gateway()
    rem(guild_id >>> 22, shards)
  end

  def get_ping(curr_shard), do: Nostrum.Util.get_all_shard_latencies()[curr_shard]
end
