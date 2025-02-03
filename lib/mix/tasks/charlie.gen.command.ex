defmodule Mix.Tasks.Charlie.Gen.Command do
  @moduledoc "Mix task to generate a command"
  use Mix.Task
  import Mix.Generator

  @shortdoc "Generates a command file"
  def run(args) do
    case args do
      [module, name] ->
        create_directory("./lib/charlie/commands/#{String.downcase(module)}")

        create_file(
          "./lib/charlie/commands/#{String.downcase(module)}/#{String.downcase(name)}.ex",
          file_content(module, name)
        )

      [name] ->
        create_file("./lib/charlie/commands/#{String.downcase(name)}.ex", file_content(name))
    end

    IO.puts(
      "Command file successfully created! Be sure to insert a new entry in the commands list"
    )
  end

  def file_content(module, name) do
    """
    defmodule Charlie.Commands.#{String.capitalize(module)}.#{String.capitalize(name)} do
      use Charlie.Command

      def aliases, do: []
      def description, do: ""
      def options, do: []
      def permissions, do: :everyone
      def predicates, do: []

      def msg_command(msg, options) do

      end

      def slash_command(interaction, options) do

      end
    end
    """
  end

  def file_content(name) do
    """
    defmodule Charlie.Commands.#{String.capitalize(name)} do
      use Charlie.Command

      def aliases, do: []
      def description, do: ""
      def options, do: []
      def permissions, do: :everyone
      def predicates, do: []

      def msg_command(msg, options) do

      end

      def slash_command(interaction, options) do
      
      end
    end
    """
  end
end
