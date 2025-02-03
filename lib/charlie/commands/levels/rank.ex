defmodule Charlie.Commands.Levels.Rank do
  use Charlie.Command

  def aliases, do: []
  def description, do: "View your or another member's rank"
  def options, do: [
    %{
      type: 6,
      name: "user",
      description: "User to query for rank",
      required: false
    }
  ]
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, options) do
    user_id =
      case options do
        [] ->
          msg.author.id

        [input] ->
          case parse_user(msg.guild_id, input) do
            :error -> msg.author.id
            {user_id, _} -> user_id
          end
      end

    {:reply, generate_rank_card(msg.guild_id, user_id)}
  end

  def slash_command(interaction, options) do
    user_id =
      case options do
        [user] -> user.value
        _ -> interaction.user.id
      end

    generate_rank_card(interaction.guild_id, user_id)
  end

  def get_user_rank(guild_id, user_id) do
    query = """
    WITH user_table AS (
      SELECT user_id, xp, rank() OVER(ORDER BY xp DESC) as rank
      FROM user_level
      WHERE guild_id = $1
    )
    SELECT user_id, xp, rank
    FROM user_table
    WHERE user_id = $2
    """

    Ecto.Adapters.SQL.query!(Charlie.Repo, query, [guild_id, user_id])
    |> Map.get(:rows)
    |> List.first()
  end

  def generate_rank_card(guild_id, user_id) do
    case get_user_rank(guild_id, user_id) do
      nil ->
        {:content, "User has not spoken yet.."}

      [user_id, xp, rank] ->
        level = Charlie.Levels.calc_level(xp)

        last_level_req = Charlie.Levels.xp_for_level(level)
        next_level_req = Charlie.Levels.xp_for_level(level + 1)

        perc =
          trunc(Float.round((xp - last_level_req) / (next_level_req - last_level_req), 2) * 100)

        user = Nostrum.Cache.UserCache.get!(user_id)
        username = user.global_name || user.username

        avatar_data =
          Nostrum.Struct.User.avatar_url(user, "png")
          |> Req.get!()
          |> Map.get(:body)
          |> Base.encode64()

        progress_width = perc * 14 + 80

        card = """
          <svg version="1.1"
         width="1600" height="400"
         xmlns="http://www.w3.org/2000/svg"
          xmlns:xlink="http://www.w3.org/1999/xlink"
         >
        <style>
        .font {
          font-family: Roboto, sans-serif;
        }
        .name {
          font-size: 50px;
          fill: rgb(255,255,255);
        }
        .discriminator {
          font-size: 20px;
          fill: rgb(255,255,255);
        }
        .stat {
          font-size: 80px;
        }
        .stat-name {
          font-size: 40px;
        }
        .rank {
          fill: rgb(255,255,255);
        }
        .level {
          fill: rgb(255,255,255);
        }
        .xp-overlay {
          font-size: 40px;
          fill: rgb(255,255,255);
        }
        </style>
        <rect width="1560" height="360" x="20" y="20" rx="20" ry="20" fill="rgba(34,39,43,255)" />
        <rect width="1480" height="80" x="60" y="260" rx="40" ry="40" fill="rgba(72,74,79,255)" />
        <rect width="#{progress_width}" height="80" x="60" y="260" rx="40" ry="40" fill="#366279" />
        <clipPath id="clipProfilePic">
        <circle r="90" cx="150" cy="140"/>
        </clipPath>
        <image id="avatar" class="avatar" x="60" y="50" width="180" height="180" clip-path="url(#clipProfilePic)" xlink:href="data:image/png;base64,#{avatar_data}" />
        <text x="270" y="120" class="font">
        <tspan class="name">#{username}</tspan>
        </text>
        <text x="270" y="220" class="font">
        <tspan class="stat-name rank">RANK:</tspan>
        <tspan dx="10" class="stat rank">#{rank}</tspan>
        <tspan dx="25" class="stat-name level">LEVEL:</tspan>
        <tspan dx="10" class="stat level">#{level}</tspan>
        </text>
        <text x="1520" y="220" class="font xp-overlay" text-anchor="end">
        #{trunc(xp - last_level_req)} / #{trunc(next_level_req - last_level_req)} xp
        </text>
        </svg>
        """

        {image, _} = Vix.Vips.Operation.svgload_buffer!(card)

        case Vix.Vips.Image.write_to_buffer(image, ".png") do
          {:ok, bin} -> {:file, {"card.png", bin}}
          _ -> {:content, "an error occurred."}
        end
    end
  end
end
