defmodule Charlie.Consumer do
  @behaviour Nostrum.Consumer
  require Logger

  def handle_event({:READY, ready, _}) do
    if not :persistent_term.get(:charlie_started, false) do
      commands = Charlie.CommandHandler.get_commands()
      case Nostrum.Api.ApplicationCommand.bulk_overwrite_global_commands(commands) do
        {:error, err} -> Logger.error("An error occurred bulk registering commands:\n#{err}")
        {:ok, _} -> Logger.info("Successfully bulk registered commands")
      end

      :persistent_term.put(:charlie_started, true)
    end

    Logger.info("#{ready.user.username} is ready!")
  end

  def handle_event({:MESSAGE_CREATE, msg, _}) when is_nil(msg.author.bot) and not is_nil(msg.guild_id) do
    prefix = Charlie.Cache.get_prefix(msg.guild_id)
    cond do
      msg.author.id == 256972966833684480 and String.starts_with?(msg.content, ",eval") -> 
        Charlie.Commands.Eval.eval(msg)
      String.starts_with?(msg.content, prefix) ->
        Charlie.CommandHandler.handle_message_command(prefix, msg)
      String.downcase(msg.content) == "@gork is this true" -> 
        Nostrum.Api.Message.create(msg.channel_id, Enum.random(["yes", "nope"]))
      true -> :noop
    end

    Charlie.Levels.handle(msg)
  end

  def handle_event({:MESSAGE_DELETE, msg, _}) when not is_nil(msg.guild_id) do
    case Charlie.Cache.get_command_msg_id(msg.id) do
      nil -> :noop
      id -> Nostrum.Api.Message.delete(msg.channel_id, id)
    end
  end

  def handle_event({:INTERACTION_CREATE, %{type: type} = interaction, _}) do
    case type do
      2 -> Charlie.CommandHandler.handle_slash_command(interaction)
    end
  end

  def handle_event({:MESSAGE_REACTION_ADD, reaction, _}) when reaction.emoji.name == "⭐" do
    Charlie.Starboard.reaction_event(:add, reaction)
  end

  def handle_event({:MESSAGE_REACTION_REMOVE, reaction, _}) when reaction.emoji.name == "⭐" do
    Charlie.Starboard.reaction_event(:remove, reaction)
  end

  def handle_event({:GUILD_CREATE, guild, _}) do
    Nostrum.Api.Message.create(1201752550307528755, "New guild join!\n\tName: #{guild.name}\n\tMembers: #{guild.member_count}")
  end

  def handle_event(_), do: :noop
end
