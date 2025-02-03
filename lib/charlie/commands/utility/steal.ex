defmodule Charlie.Commands.Utility.Steal do
  use Charlie.Command

  def aliases, do: []
  def description, do: "Steal a emoji or sticker and have it added to your server!"
  def options, do: [
    %{
      type: 3,
      name: "emoji",
      description: "The emoji to steal",
      required: true,
    }
  ]
  def permissions, do: [:manage_emojis_and_stickers]
  def predicates, do: [Predicates.has_permission(:manage_emojis_and_stickers)]

  def msg_command(msg, options) do
    resp = case options do
      [] -> case msg.sticker_items do
        nil -> {:error, "Please specify a emoji or sticker!"}
        [sticker] -> get_sticker(sticker)
      end
      [emoji] -> get_emoji(emoji)
      _ -> {:error, "You may only do 1 emoji at a time!"}
    end

    resp = case resp do
      {:error, ret_msg} -> ret_msg
      {:emoji, emoji} -> maybe_create_emoji(emoji, msg.guild_id)
      {:sticker, sticker} -> maybe_create_sticker(sticker, msg.guild_id)
    end

    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{value: content}]) do
    resp = case get_emoji(content) do
      {:error, ret_msg} -> ret_msg
      {:emoji, emoji} -> maybe_create_emoji(emoji, interaction.guild_id)
    end

    [:ephemeral, {:content, resp}]
  end

  def maybe_create_emoji([name, data], guild_id) do
    case Nostrum.Api.Guild.create_emoji(guild_id, name: name, image: data) do
      {:ok, emoji} -> "Emoji has been successfully stolen! #{Nostrum.Struct.Emoji.mention(emoji)}"
      {:error, %{response: %{code: 30008}}} -> "Could not upload emoji! Max number of emojis in this server reached."
      {:error, %{response: %{code: 30018}}} -> "Could not upload emoji! Max number of animated emojis in this server reached."
      _ -> "An error occurred creating the emoji."
    end
  end

  def maybe_create_sticker(file, guild_id) do
    case send_request(guild_id, file) do
      {:ok, _} -> "Sticker successfully stolen!"
      {:ok} -> "Sticker successfully stolen!"
      {:error, %{response: %{code: 30039}}} -> "Could not upload sticker! Max number of stickers in this server reached."
      _ -> "An error occurred creating the sticker."
    end
  end

  def get_emoji(content) do
    case Regex.run(~r/<(a)?:(\w+):(\d+)>/, content) do
      nil -> {:error, "Could not find any valid emojis"}
      [_, animated, name, id] -> 
        format = if animated == "a", do: "gif", else: "png"
        case Req.get(URI.encode(Nostrum.Constants.cdn_url() <> "/emojis/#{id}.#{format}")) do
          {:ok, %{status: 200, body: body}} -> {:emoji, [name, "data:image/#{format};base64,#{Base.encode64(body)}"]}
          _ -> {:error, "Emoji not found"}
        end
    end
  end

  def get_sticker(%{id: sticker_id, name: sticker_name}) do
    case Req.get(URI.encode(Nostrum.Constants.cdn_url() <> "/stickers/#{sticker_id}.png")) do
      {:ok, %{status: 200, body: body}} -> {:sticker, [sticker_name, body]}
      _ -> {:error, "Sticker not found"}
    end
  end

  def send_request(guild_id, file) do
    boundary = String.duplicate("-", 20) <> "KraigieNostrumCat_" <> Base.encode16(:crypto.strong_rand_bytes(10))
    %{
      method: :post,
      route: "/guilds/#{guild_id}/stickers",
      body: {:multipart, gen_multipart(file, boundary)},
      params: [],
      headers: [
        {"content-type", "multipart/form-data; boundary=#{boundary}"}
      ]
    }
    |> Nostrum.Api.Ratelimiter.queue()
  end

  def gen_multipart([name, data], boundary) do
    file_mime = "image/png"
    file_size = :erlang.iolist_size(data)

    [
      ~s|--#{boundary}\r\n|,
      ~s|content-length: #{file_size}\r\n|,
      ~s|content-type: #{file_mime}\r\n|,
      ~s|content-disposition: form-data; name="file"; filename="#{name}.png"\r\n\r\n|,
      data,
      ~s|\r\n--#{boundary}\r\n|,
      ~s|content-disposition: form-data; name="name"\r\n\r\n|,
      name,
      ~s|\r\n--#{boundary}\r\n|,
      ~s|content-disposition: form-data; name="tags"\r\n\r\n|,
      name,
      ~s|\r\n--#{boundary}\r\n|,
      ~s|content-disposition: form-data; name="description"\r\n\r\n|,
      ~s|\r\n--#{boundary}--\r\n|
    ]
  end
end
