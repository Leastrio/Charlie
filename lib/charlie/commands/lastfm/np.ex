defmodule Charlie.Commands.Lastfm.Np do
  use Charlie.Command
  import Nostrum.Struct.Embed
  import Ecto.Query, only: [from: 2]

  def aliases, do: ["fm"]
  def description, do: "Show your recently played song"
  def options, do: []
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, _) do
    case generate_embed(msg.author) do
      {:content, _} = resp -> {:reply, resp}
      {:embed, _} = resp -> {:fm, resp}
    end
  end

  def slash_command(interaction, _) do
    generate_embed(interaction.user)
  end

  def generate_embed(user) do
    lastfm_username = Charlie.Repo.one(from(u in Charlie.Schema.User, where: u.user_id == ^user.id, select: u.lastfm_username))
    if is_nil(lastfm_username) do 
      {:content, "Last.fm account is not linked. To link use the `,link` command"}
    else
      track = Charlie.Lastfm.get_latest(lastfm_username)
      case track do
        {:ok, track} ->
          avatar_url = Nostrum.Struct.User.avatar_url(user)
          embed = %Nostrum.Struct.Embed{}
          |> put_author("Last.fm: #{lastfm_username}", "https://last.fm/user/#{lastfm_username}", avatar_url)
          |> put_description("**Track**:\n[#{track.title} - #{track.artist}](#{track.url})")
          |> put_thumbnail(track.image)
          |> put_footer("Album: #{track.album}")
          |> put_color(0x1DB954)

          {:embed, embed}
        {_err, msg} -> {:content, msg}
      end
    end
  end
end
