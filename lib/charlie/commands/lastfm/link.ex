defmodule Charlie.Commands.Lastfm.Link do
  use Charlie.Command

  def aliases, do: []
  def description, do: "Link your Last.fm account to the bot"
  def options, do: [
    %{
      type: 3,
      name: "username",
      description: "Your Last.fm username",
      required: true
    }
  ]
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, options) do
    resp = case options do
      [username] -> link_username(msg.author.id, username)
      _ -> "Please provide a username with the command! ex. ,link charlie"
    end
    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{value: username}]) do
    [:ephemeral, {:content, link_username(interaction.user.id, username)}]
  end

  def link_username(user_id, username) do
    case Charlie.Lastfm.get_latest(username) do
      {:username_error, msg} -> msg
      res ->
        Charlie.Repo.insert!(
          %Charlie.Schema.User{user_id: user_id, lastfm_username: username},
          on_conflict: [set: [lastfm_username: username]],
          conflict_target: :user_id
        )
        case res do
          {:private_error, _} -> "Successfully linked! Your recent plays are privated, please fix."
          _ -> "Successfully linked!"
        end
    end
  end
end
