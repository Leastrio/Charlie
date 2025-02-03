defmodule Charlie.Commands.Information.Help do
  use Charlie.Command
  import Nostrum.Struct.Embed

  def aliases, do: ["commands"]
  def description, do: "Show all commands"
  def options, do: [
    %{
      type: 3,
      name: "command",
      description: "The command to view specific help on",
      required: false
    }
  ]
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, options) do
    guild = Nostrum.Cache.GuildCache.get!(msg.guild_id)
    member_perms = Nostrum.Struct.Guild.Member.guild_permissions(msg.member, guild)

    case options do
      [] ->
        {:reply, {:embed, gen_response(guild, msg.author.id, member_perms)}}

      [command] ->
        lower = String.downcase(command)

        case Charlie.CommandHandler.commands() |> Map.fetch(lower) do
          {:ok, module} ->
            resp = gen_command_help(lower, module)

            if String.length(resp) > 1990 do
              {:reply, {:file, {"help.txt", resp}}}
            else
              {:reply, {:content, "```\n#{resp}\n```"}}
            end

          _ ->
            {:reply, {:content, "Command not found."}}
        end

      _ ->
        {:reply, {:content, "Invalid usage! ex. `,help [command]`"}}
    end
  end

  def slash_command(interaction, options) do
    resp =
      case options do
        nil ->
          guild = Nostrum.Cache.GuildCache.get!(interaction.guild_id)
          member_perms = Nostrum.Struct.Guild.Member.guild_permissions(interaction.member, guild)
          {:embed, gen_response(guild, interaction.user.id, member_perms)}

        [%{name: "command", value: command}] ->
          lower = String.downcase(command)

          case Charlie.CommandHandler.commands() |> Map.fetch(lower) do
            {:ok, module} ->
              resp = gen_command_help(lower, module)

              if String.length(resp) > 1990 do
                {:file, {"help.txt", resp}}
              else
                {:content, "```\n#{resp}\n```"}
              end

            _ ->
              {:content, "Command not found."}
          end
      end

    resp
  end

  def gen_response(guild, author_id, perms) do
    commands =
      Charlie.CommandHandler.commands()
      |> Enum.flat_map(fn {name, module} ->
        case apply(module, :permissions, []) do
          :everyone ->
            [{name, module}]

          :noone ->
            []

          req_perms ->
            if guild.owner_id == author_id or :administrator in perms or
                 Enum.all?(req_perms, &Enum.member?(perms, &1)) do
              [{name, module}]
            else
              []
            end
        end
      end)
      |> Enum.group_by(&find_category/1)
      |> Map.to_list()

    %Nostrum.Struct.Embed{}
    |> put_title("Help")
    |> put_description(
      "To view help for a specific command, run the help command with the name of the command as an argument.\nEx. `,help birthday`"
    )
    |> add_field(commands)
    |> put_color(0x7e93ba)
  end

  def add_field(embed, []), do: embed

  def add_field(embed, [{category, commands} | rest]) do
    embed
    |> put_field(category, Enum.map(commands, fn {name, _} -> name end) |> Enum.join("\n"), true)
    |> add_field(rest)
  end

  def find_category({_, module}) do
    case Atom.to_string(module) |> String.split(".") do
      ["Elixir", "Charlie", "Commands", category, _] -> category
      ["Elixir", "Charlie", "Commands", _] -> "Misc"
    end
  end

  def gen_command_help(name, module) do
    args = apply(module, :options, [])
    has_sub_cmd? = Enum.any?(args, fn o -> o.type == 1 end)

    usage_line =
      if has_sub_cmd? do
        if Enum.any?(args, fn o -> o.type == 1 and Map.has_key?(o, :options) end) do
          "Usage: ,#{name} [command] [args]"
        else
          "Usage: ,#{name} [command]"
        end
      else
        if args == [] do
          "Usage: ,#{name}"
        else
          "Usage: ,#{name} [args]"
        end
      end

    commands_line =
      if has_sub_cmd? do
        pad =
          if Enum.any?(args, fn o -> Map.has_key?(o, :options) end) do
            longest =
              Enum.max_by(args, fn o ->
                if Map.has_key?(o, :options) do
                  String.length(
                    "#{o.name} " <>
                      Enum.join(Enum.map(o.options, fn op -> "{#{op.name}}" end), " ")
                  )
                else
                  String.length("#{o.name}")
                end
              end)

            ("#{longest.name} " <>
               Enum.join(Enum.map(longest.options, fn op -> "{#{op.name}}" end), " "))
            |> String.length()
            |> Kernel.+(2)
          else
            Enum.max_by(args, fn o -> String.length("#{o.name}") end)
            |> Map.fetch!(:name)
            |> String.length()
            |> Kernel.+(3)
          end

        "\nCommands:\n\t" <>
          Enum.join(
            Enum.map(args, fn o ->
              if Map.has_key?(o, :options) do
                String.pad_trailing(
                  "#{o.name} " <>
                    Enum.join(Enum.map(o.options, fn op -> "{#{op.name}}" end), " "),
                  pad
                ) <> " #{o.description}"
              else
                "#{String.pad_trailing("#{o.name}", pad)} #{o.description}"
              end
            end),
            "\n\t"
          )
      else
        if args == [] do
          ""
        else
          pad =
            Enum.max_by(args, fn o -> String.length("{#{o.name}}") end)
            |> Map.fetch!(:name)
            |> String.length()
            |> Kernel.+(4)

          "\nArgs:\n\t" <>
            Enum.join(
              Enum.map(args, fn o ->
                "#{String.pad_trailing("{#{o.name}}", pad)} #{o.description}"
              end),
              "\n\t"
            )
        end
      end

    """
    #{usage_line}

    #{apply(module, :description, [])}
    #{commands_line}
    """
  end
end
