defmodule Charlie.Commands.Information.Stats do
  use Charlie.Command
  import Nostrum.Struct.Embed

  @git_hash String.trim(elem(System.cmd("git", ["rev-parse", "HEAD"]), 0))

  def aliases, do: []
  def description, do: "View the stats of Charlie"
  def options, do: []
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(_, _) do
    {:reply, {:embed, gen_embed()}}
  end

  def slash_command(_, _) do
    {:embed, gen_embed()}
  end

  def gen_embed() do
    {uptime, _} = :erlang.statistics(:wall_clock)
    mem_usage = :erlang.memory(:total) |> div(1024 * 1024)

    uptime =
      uptime
      |> Timex.Duration.from_milliseconds()
      |> Timex.Format.Duration.Formatter.format(:humanized)

    %Nostrum.Struct.Embed{}
    |> put_title("Charlie Stats")
    |> put_color(0x366279)
    |> put_field("Uptime", uptime, true)
    |> put_field("Commit Hash", String.slice(@git_hash, 0..5), true)
    |> put_field("Build Info", System.build_info().build, true)
    |> put_field("Memory Usage", "#{mem_usage} MiB", true)
  end
end
