defmodule Charlie.Commands.Eval do
  def eval(msg) do
    formatted_code =
      msg.content
      |> String.trim_leading(",eval")
      |> String.trim()
      |> String.trim_leading("```elixir")
      |> String.trim_leading("```ex")
      |> String.trim_trailing("```")

    {:ok, pid} = StringIO.open("\n\n")

    eval =
      Task.async(fn ->
        Process.group_leader(self(), pid)

        try do
          {result, _binding} = Code.eval_string(formatted_code, [msg: msg], __ENV__)
          result
        rescue
          err -> err
        end
      end)
      |> Task.await()

    output =
      (inspect(eval) <> (StringIO.contents(pid) |> Tuple.to_list() |> Enum.join("\n")))
      |> clean_output()

    StringIO.close(pid)

    if String.length(output) > 1990 do
      Nostrum.Api.Message.create(msg.channel_id,
        file: %{name: "output.txt", body: output},
        message_reference: %{message_id: msg.id}
      )
    else
      Nostrum.Api.Message.create(msg.channel_id,
        content: "```\n#{output}\n```",
        message_reference: %{message_id: msg.id}
      )
    end
  end

  def clean_output(output) do
    output |> String.replace(Application.get_env(:nostrum, :token), "token")
  end
end
