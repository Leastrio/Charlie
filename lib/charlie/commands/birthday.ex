defmodule Charlie.Commands.Birthday do
  use Charlie.Command
  import Ecto.Query, only: [from: 2]
  alias Charlie.Repo
  alias Charlie.Schema

  def aliases, do: ["bday"]
  def description, do: "Set your birthday to get pinged in a channel(if set) when that date hit!"
  def options, do: [
    %{
      type: 1,
      name: "remove",
      description: "Remove your birthday"
    },
    %{
      type: 1,
      name: "remember",
      description: "Set your birthday",
      options: [
        %{
          type: 3,
          name: "date",
          description: "Your birthday in the following formats: mm-dd, mm-dd-yyyy",
          required: true
        }
      ]
    }
  ]
  def permissions, do: :everyone
  def predicates, do: []

  def msg_command(msg, options) do
    resp = if Repo.exists?(from(g in Schema.Guild, where: g.guild_id == ^msg.guild_id and (not is_nil(g.birthday_channel_id)))) do
      case options do
          ["remember"] -> "Please specify a date! ex. `,birthday remember 01-02`.\nThe following formats are accepted: mm-dd, mm-dd-yyyy"

          ["remove"] ->
            {deleted, _} = Repo.delete_all(from(b in Schema.Birthday, where: b.guild_id == ^msg.guild_id and b.user_id == ^msg.author.id))
            if deleted > 0 do
              "Birthday forgotten!"
            else
              "You have not set a birthday!"
            end

          ["remember", date] ->
            case parse_date(date) do
              :error -> "Could not parse date provided, make sure date provided is in the format of: mm-dd or mm-dd-yyyy"

              %{day: d, month: m, year: y} ->
                %Schema.Birthday{
                  guild_id: msg.guild_id,
                  user_id: msg.author.id,
                  day: d,
                  month: m,
                  year: y
                }
                |> Repo.insert(
                  on_conflict: [set: [day: d, month: m, year: y]],
                  conflict_target: [:guild_id, :user_id]
                )

                "I will remember your birthday on #{m}-#{d}!"
            end

          _ ->
            "Invalid usage! ex. `,birthday remember 01-02`.\nThe following formats are accepted: mm-dd, mm-dd-yyyy"
        end
    else
      "This server does not have a birthday channel set!"
    end

    {:reply, {:content, resp}}
  end

  def slash_command(interaction, [%{name: "remember", options: [%{name: "date", value: date}]}]) do
    resp = if Repo.exists?(from(g in Schema.Guild, where: g.guild_id == ^interaction.guild_id and (not is_nil(g.birthday_channel_id)))) do
      case parse_date(date) do
          :error ->
            "Could not parse date provided, make sure date provided is in the format of: mm-dd or mm-dd-yyyy"

          %{day: d, month: m, year: y} ->
            %Schema.Birthday{
              guild_id: interaction.guild_id,
              user_id: interaction.user.id,
              day: d,
              month: m,
              year: y
            }
            |> Repo.insert(
              on_conflict: [set: [day: d, month: m, year: y]],
              conflict_target: [:guild_id, :user_id]
            )

            "I will remember your birthday on #{m}-#{d}!"
        end
    else
      "This server does not have a birthday channel set!"
    end

    {:content, resp}
  end

  def slash_command(interaction, [%{name: "remove"}]) do
    resp = if Repo.exists?(from(g in Schema.Guild, where: g.guild_id == ^interaction.guild_id and (not is_nil(g.birthday_channel_id)))) do
      {deleted, _} = Repo.delete_all(from(b in Schema.Birthday, where: b.guild_id == ^interaction.guild_id and b.user_id == ^interaction.user.id))
      if deleted > 0 do
        "Birthday forgotten!"
      else
        "You have not set a birthday!"
      end
    else
      "This server does not have a birthday channel set!"
    end

    {:content, resp}
  end

  def parse_date(date_string) do
    case Regex.run(~r/(\d{1,2})-(\d{1,2})(?:-(\d{4}))?/, date_string) do
      [_, month, day] ->
        %{day: String.to_integer(day), month: String.to_integer(month), year: nil}

      [_, month, day, year] ->
        %{
          day: String.to_integer(day),
          month: String.to_integer(month),
          year: String.to_integer(year)
        }

      _ ->
        :error
    end
  end
end
