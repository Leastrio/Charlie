defmodule Charlie.Starboard do
  import Nostrum.Struct.Embed
  import Bitwise
  import Ecto.Query, only: [from: 2]
  alias Charlie.Schema
  alias Charlie.Repo
  require Logger

  def reaction_event(type, reaction) do
    config = from(sc in Schema.Starboard, where: sc.guild_id == ^reaction.guild_id) |> Repo.one()

    if (not is_nil(config)) and config.active and reaction.channel_id != config.channel_id do
      {:ok, message} = Nostrum.Api.Message.get(reaction.channel_id, reaction.message_id)
      count = count_stars(message.reactions)
      if count >= config.threshold do
        case type do
          :add -> handle_star_add(message, count, config)
          :remove -> handle_star_remove(message, count, config)
        end
      end
    end
  end

  def count_stars(reactions) do
    if is_nil(reactions) do
      0
    else
      Enum.find(reactions, fn r -> r.emoji.name == "⭐" end).count
    end
  end

  def handle_star_add(msg, count, config) do
    query = from(se in Schema.StarboardEntry, where: se.message_id == ^msg.id)
    case Repo.one(query) do
      nil -> create_star(msg, count, config)
      entry -> edit_star(msg, entry.bot_message_id, count, config)
    end
  end

  def handle_star_remove(msg, count, config) do
    query = from(se in Schema.StarboardEntry, where: se.message_id == ^msg.id)
    case Repo.one(query) do
      nil -> :noop
      entry -> edit_star(msg, entry.bot_message_id, count, config)
    end
  end

  def create_star(msg, count, config) do
    {:ok, star_msg} =
      Nostrum.Api.Message.create(
        config.channel_id,
        content: "#{star_emoji(count)} **#{count}** <##{msg.channel_id}>",
        embeds: [gen_embed(msg, count)],
        components: [
          %{
            type: 1,
            components: [
              %{
                type: 2,
                style: 5,
                label: "Jump to message",
                url: jump_url(config.guild_id, msg.channel_id, msg.id)
              }
            ]
          }
        ]
      )
    %Schema.StarboardEntry{message_id: msg.id, guild_id: config.guild_id, channel_id: msg.channel_id, bot_message_id: star_msg.id}
    |> Repo.insert!()
  end

  def edit_star(msg, bot_msg_id, count, config) do
    Nostrum.Api.Message.edit(
      config.channel_id,
      bot_msg_id,
      content: "#{star_emoji(count)} **#{count}** <##{msg.channel_id}>",
      embeds: [gen_embed(msg, count)],
      components: [
        %{
          type: 1,
          components: [
            %{
              type: 2,
              style: 5,
              label: "Jump to message",
              url: jump_url(config.guild_id, msg.channel_id, msg.id)
            }
          ]
        }
      ]
    )
  end

  def gen_embed(msg, count) do
    %Nostrum.Struct.Embed{}
    |> put_author(msg.author.username, "", Nostrum.Struct.User.avatar_url(msg.author))
    |> put_color(gen_color(count))
    |> put_timestamp(DateTime.to_iso8601(msg.timestamp))
    |> maybe_put_image(msg)
    |> description(msg)
  end

  def maybe_put_image(embed, msg) do
    with [head | _tail] <- msg.attachments,
         true <- String.ends_with?(head.url, [".png", ".jpeg", ".jpg", ".gif", "webp"]) do
          put_image(embed, head.url)
    else
      _ -> embed
    end
  end

  def description(embed, msg) do
    case msg.attachments do
      [] -> put_description(embed, msg.content)
      _ -> put_description(embed, "#{msg.content}\n**Message contained attachment(s)**")
    end
  end

  def gen_color(stars) do
    p =
      cond do
        stars / 13 > 1.0 -> 1.0
        true -> stars / 13
      end

    red = 255
    green = trunc(194 * p + 253 * (1 - p))
    blue = trunc(12 * p + 247 * (1 - p))
    (red <<< 16) + (green <<< 8) + blue
  end

  def jump_url(guild_id, channel_id, msg_id) do
    "https://discord.com/channels/#{guild_id}/#{channel_id}/#{msg_id}"
  end

  def star_emoji(stars) do
    cond do
      5 > stars -> "⭐"
      10 > stars and stars >= 5 -> "🌟"
      25 > stars and stars >= 10 -> "💫"
      true -> "✨"
    end
  end
end
