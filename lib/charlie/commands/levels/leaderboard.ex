defmodule Charlie.Commands.Levels.Leaderboard do
  use Charlie.Command
  import Nostrum.Struct.Embed

  def aliases, do: ["lb", "top"]
  def description, do: "View the top ranks in the server"
  def options, do: []
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, _), do: {:reply, {:embed, generate_embed(msg.guild_id, msg.author.id)}}

  def slash_command(interaction, _), do: {:embed, generate_embed(interaction.guild_id, interaction.user.id)}

  def get_top_with_user(guild_id, user_id) do
    query = """
    WITH user_table AS (
      SELECT user_id, xp, rank() OVER(ORDER BY xp DESC) as rank
      FROM user_level
      WHERE guild_id = $1
    )
    (SELECT user_id, xp, rank
      FROM user_table
      ORDER BY xp DESC
      LIMIT 10)
    UNION
    SELECT user_id, xp, rank
    FROM user_table
    WHERE user_id = $2
    ORDER BY xp DESC
    """

    Ecto.Adapters.SQL.query!(Charlie.Repo, query, [guild_id, user_id])
    |> Map.get(:rows)
  end

  def generate_embed(guild_id, invoker_id) do
    %Nostrum.Struct.Embed{}
    |> put_title("Rank Leaderboard")
    |> put_color(6_669_007)
    |> put_description(
      gen_desc("", get_top_with_user(guild_id, invoker_id), invoker_id)
    )
  end

  def gen_desc(_desc, [], _invoker_id), do: "No data found.."

  def gen_desc(desc, [head | tail], invoker_id) do
    case tail do
      [] -> desc <> "\n" <> gen_rank(head, invoker_id)
      _ -> gen_desc(desc <> "\n" <> gen_rank(head, invoker_id), tail, invoker_id)
    end
  end

  def gen_rank([user_id, xp, rank], invoker_id) do
    cond do
      user_id == invoker_id ->
        "**#{rank}: <@#{user_id}> Level: #{Charlie.Levels.calc_level(xp)}**"

      true ->
        "#{rank}: <@#{user_id}> Level: #{Charlie.Levels.calc_level(xp)}"
    end
  end
end
