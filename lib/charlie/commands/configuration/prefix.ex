defmodule Charlie.Commands.Configuration.Prefix do
  use Charlie.Command

  def aliases, do: []
  def description, do: "Configure the bot's prefix"
  def options, do: [
    %{
      type: 3,
      name: "prefix",
      description: "The prefix to change to",
      required: true,
      max_length: 10
    }
  ]
  def permissions, do: [:manage_guild]
  def predicates, do: [Predicates.has_permission(:manage_guild)]

  def msg_command(msg, options) do
    resp = case options do
      [] -> "Invalid Usage! ex. `,prefix !`"
      _ ->
        set_prefix(msg.guild_id, Enum.join(options))
    end
    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{value: prefix}]) do
    {:content, set_prefix(interaction.guild_id, prefix)}
  end

  def set_prefix(guild_id, prefix) do
    if String.length(prefix) < 10 do
      %Charlie.Schema.Guild{guild_id: guild_id, prefix: prefix}
      |> Charlie.Repo.insert(on_conflict: [set: [prefix: prefix]], conflict_target: :guild_id)

      Charlie.Cache.insert_prefix(guild_id, prefix)
      "The prefix for this server is now set to: `#{prefix}`"
    else
      "Invalid Prefix, Prefixes are limited to 10 characters!"
    end
  end
end
